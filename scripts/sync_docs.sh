#!/bin/bash
# 文档同步脚本:在CLAUDE.md和CODEBUDDY.md之间同步内容
# 用法: ./scripts/sync_docs.sh [source_file]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# 定义文件路径
CLAUDE_MD="$PROJECT_DIR/CLAUDE.md"
CODEBUDDY_MD="$PROJECT_DIR/CODEBUDDY.md"
TIMESTAMP_FILE="$PROJECT_DIR/.sync_timestamp"

# 颜色输出
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查文件是否存在
check_files() {
    if [ ! -f "$CLAUDE_MD" ]; then
        log_error "文件不存在: $CLAUDE_MD"
        exit 1
    fi

    if [ ! -f "$CODEBUDDY_MD" ]; then
        log_error "文件不存在: $CODEBUDDY_MD"
        exit 1
    fi
}

# 获取文件修改时间
get_mtime() {
    if [ "$(uname)" = "Darwin" ]; then
        stat -f "%m" "$1"
    else
        stat -c "%Y" "$1"
    fi
}

# 双向同步策略
bidirectional_sync() {
    log_info "开始双向同步..."

    local claude_mtime=$(get_mtime "$CLAUDE_MD")
    local buddy_mtime=$(get_mtime "$CODEBUDDY_MD")

    # 读取上一次同步时间戳
    local last_sync=0
    if [ -f "$TIMESTAMP_FILE" ]; then
        last_sync=$(cat "$TIMESTAMP_FILE")
    fi

    local claude_changed=false
    local buddy_changed=false

    # 检查哪个文件被修改过
    if [ "$claude_mtime" -gt "$last_sync" ]; then
        claude_changed=true
        log_info "检测到 CLAUDE.md 有更新"
    fi

    if [ "$buddy_mtime" -gt "$last_sync" ]; then
        buddy_changed=true
        log_info "检测到 CODEBUDDY.md 有更新"
    fi

    # 如果两个文件都被修改过,需要处理冲突
    if [ "$claude_changed" = true ] && [ "$buddy_changed" = true ]; then
        log_warning "两个文件都被修改,执行智能合并..."

        # 提取各自特有的章节
        merge_content "$CLAUDE_MD" "$CODEBUDDY_MD" "$CODEBUDDY_MD"
        merge_content "$CODEBUDDY_MD" "$CLAUDE_MD" "$CLAUDE_MD"

        log_success "完成智能合并"
    elif [ "$claude_changed" = true ]; then
        log_info "从 CLAUDE.md 同步到 CODEBUDDY.md..."
        sync_to_codebuddy
    elif [ "$buddy_changed" = true ]; then
        log_info "从 CODEBUDDY.md 同步到 CLAUDE.md..."
        sync_to_claude
    else
        log_info "没有检测到文件更改"
    fi

    # 更新同步时间戳
    echo "$(date +%s)" > "$TIMESTAMP_FILE"
    log_success "同步完成"
}

# 从CLAUDE.md同步到CODEBUDDY.md
sync_to_codebuddy() {
    # 提取CLAUDE.md中CODEBUDDY.md没有的独特内容
    local unique_content=$(extract_unique_content "$CLAUDE_MD" "$CODEBUDDY_MD")

    if [ -n "$unique_content" ]; then
        log_info "添加以下内容到 CODEBUDDY.md:"
        echo "$unique_content"
        echo "" >> "$CODEBUDDY_MD"
        echo "$unique_content" >> "$CODEBUDDY_MD"
        log_success "已更新 CODEBUDDY.md"
    fi
}

# 从CODEBUDDY.md同步到CLAUDE.md
sync_to_claude() {
    # 提取CODEBUDDY.md中CLAUDE.md没有的独特内容
    local unique_content=$(extract_unique_content "$CODEBUDDY_MD" "$CLAUDE_MD")

    if [ -n "$unique_content" ]; then
        log_info "添加以下内容到 CLAUDE.md:"
        echo "$unique_content"

        # 在Repository-Specific Information部分前插入
        if grep -q "# Repository-Specific Information" "$CLAUDE_MD"; then
            sed -i '' '/# Repository-Specific Information/i \
\
'"$unique_content"'
            ' "$CLAUDE_MD"
        else
            echo "" >> "$CLAUDE_MD"
            echo "$unique_content" >> "$CLAUDE_MD"
        fi
        log_success "已更新 CLAUDE.md"
    fi
}

# 提取文件A中文件B没有的独特内容
extract_unique_content() {
    local file_a="$1"
    local file_b="$2"

    # 使用比较策略:提取A中有但B中没有的章节
    python3 - << PYTHON_EOF
import re

with open("$file_a", 'r') as f:
    content_a = f.read()

with open("$file_b", 'r') as f:
    content_b = f.read()

# 分割为章节
def split_sections(content):
    sections = []
    lines = content.split('\n')
    current_section = []
    current_header = None

    for line in lines:
        if re.match(r'^#{1,3}\s+', line):
            if current_header:
                sections.append((current_header, '\n'.join(current_section)))
            current_header = line.strip()
            current_section = [line]
        else:
            current_section.append(line)

    if current_header:
        sections.append((current_header, '\n'.join(current_section)))

    return sections

sections_a = split_sections(content_a)
sections_b = split_sections(content_b)

# 获取B中的所有章节标题
headers_b = {section[0] for section in sections_b}

# 找出A中B没有的章节
unique = []
for header, content in sections_a:
    if header not in headers_b and header:
        unique.append(content)

print('\n\n'.join(unique))
PYTHON_EOF
}

# 智能合并两个文件的内容
merge_content() {
    local source="$1"
    local target="$2"
    local output="$3"

    python3 - << PYTHON_EOF
import re

with open("$source", 'r') as f:
    source_content = f.read()

with open("$target", 'r') as f:
    target_content = f.read()

def split_sections(content):
    sections = {}
    lines = content.split('\n')
    current_header = None
    current_section = []

    for line in lines:
        if re.match(r'^#{1,3}\s+', line):
            if current_header:
                sections[current_header] = '\n'.join(current_section)
            current_header = line.strip()
            current_section = [line]
        else:
            current_section.append(line)

    if current_header:
        sections[current_header] = '\n'.join(current_section)

    return sections

source_sections = split_sections(source_content)
target_sections = split_sections(target_content)

# 合并章节:目标优先,但补充源中的独特章节
merged = target_sections.copy()

for header, content in source_sections.items():
    if header not in merged:
        merged[header] = content

# 按原始顺序重建内容
with open("$output", 'w') as f:
    for header in target_sections.keys():
        if header in merged:
            f.write(merged[header] + '\n\n')

    # 添加源中独有的章节
    for header, content in source_sections.items():
        if header not in target_sections:
            f.write(content + '\n\n')
PYTHON_EOF
}

# 主函数
main() {
    local source_file="$1"

    check_files

    if [ -n "$source_file" ]; then
        log_info "指定源文件: $source_file"
        if [ "$source_file" = "claude" ]; then
            sync_to_codebuddy
            echo "$(date +%s)" > "$TIMESTAMP_FILE"
        elif [ "$source_file" = "codebuddy" ]; then
            sync_to_claude
            echo "$(date +%s)" > "$TIMESTAMP_FILE"
        else
            log_error "无效的源文件参数,使用 'claude' 或 'codebuddy'"
            exit 1
        fi
    else
        bidirectional_sync
    fi
}

# 执行主函数
main "$@"
