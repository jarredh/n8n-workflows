#!/bin/bash
# 使用 fswatch 监控文件变更并自动同步
# 安装: brew install fswatch

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

CLAUDE_MD="$PROJECT_DIR/CLAUDE.md"
CODEBUDDY_MD="$PROJECT_DIR/CODEBUDDY_MD"
SYNC_SCRIPT="$SCRIPT_DIR/sync_docs.sh"

# 颜色输出
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}=== 文档自动同步守护进程 ===${NC}"
echo -e "${YELLOW}监控文件:${NC}"
echo "  - CLAUDE.md"
echo "  - CODEBUDDY.md"
echo ""
echo -e "${YELLOW}按 Ctrl+C 停止${NC}"
echo ""

# 检查 fswatch 是否安装
if ! command -v fswatch &> /dev/null; then
    echo "错误: fswatch 未安装"
    echo "请运行: brew install fswatch"
    exit 1
fi

# 监控文件变更
fswatch -o "$PROJECT_DIR" -e ".*" -i "^CLAUDE\.md$" -i "^CODEBUDDY\.md$" --event=Updated "$CLAUDE_MD" "$CODEBUDDY_MD" | while read; do
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} 检测到文件变更,开始同步..."
    
    # 稍作延迟,等待文件写入完成
    sleep 0.5
    
    # 执行同步
    "$SYNC_SCRIPT" > /dev/null 2>&1
    
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} 同步完成"
    echo ""
done
