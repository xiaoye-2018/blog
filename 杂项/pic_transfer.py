import re
from pathlib import Path

# ==============================
# 配置区域
# ==============================

# GitHub 用户名
GITHUB_USER = "xiaoye-2018"

# 仓库名
REPO_NAME = "code-note"
# 分支
BRANCH = "master"

# markdown 根目录
MARKDOWN_DIR = "./netty"

# ==============================


def replace_img(match, md_file):
    alt_text = match.group(1)
    img_path = match.group(2)

    # 当前 md 文件所在目录
    md_dir = md_file.parent

    # 图片绝对路径
    full_img_path = (md_dir / img_path).resolve()

    # 仓库根目录
    repo_root = Path(MARKDOWN_DIR).resolve()

    # 转换为仓库相对路径
    relative_path = full_img_path.relative_to(repo_root)

    # 统一路径分隔符
    relative_path = str(relative_path).replace("\\", "/")

    # jsDelivr 地址
    cdn_url = (
        f"https://cdn.jsdelivr.net/gh/"
        f"{GITHUB_USER}/{REPO_NAME}@{BRANCH}/{relative_path}"
    )

    return f"![{alt_text}]({cdn_url})"


def process_md_file(md_file):
    content = md_file.read_text(encoding="utf-8")

    pattern = re.compile(r'!\[(.*?)\]\((.*?)\)')

    new_content = pattern.sub(
        lambda m: replace_img(m, md_file),
        content
    )

    md_file.write_text(new_content, encoding="utf-8")

    print(f"✅ 已处理: {md_file}")


def main():
    md_files = Path(MARKDOWN_DIR).rglob("*.md")

    for md_file in md_files:
        process_md_file(md_file)


if __name__ == "__main__":
    main()