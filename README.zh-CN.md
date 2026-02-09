# Awesome AWESOME

> 一个专门收录优质 `awesome-xxx` 仓库的精选索引。

[![Awesome](https://awesome.re/badge.svg)](https://awesome.re)
[![English README](https://img.shields.io/badge/README-English-blue)](README.md)

`awesome-awesome` 聚焦高质量、持续维护的 `awesome-xxx` 清单与资源索引。

## 为什么要做这个仓库

`awesome-xxx` 仓库数量非常多。这个项目帮助你：

- 更快发现可信、活跃、实用的 awesome 清单。
- 按主题导航，而不是盲目搜索。
- 通过简单的贡献规范和校验规则保持质量。

## 快速开始

- 浏览分类目录：[`categories/`](categories/)
- 阅读收录规则：[`CONTRIBUTING.zh-CN.md`](CONTRIBUTING.zh-CN.md)
- 提交包含推荐仓库的 PR

## 治理与规范

- 校验脚本：[`scripts/validate.sh`](scripts/validate.sh)
- 链接检查脚本：[`scripts/check-links.sh`](scripts/check-links.sh)
- Star 排行脚本：[`scripts/generate-star-ranking.sh`](scripts/generate-star-ranking.sh)
- CI 工作流：[`.github/workflows/validate.yml`](.github/workflows/validate.yml)
- 定时死链检查工作流：[`.github/workflows/link-check.yml`](.github/workflows/link-check.yml)
- 定时 Star 排行更新工作流：[`.github/workflows/star-ranking.yml`](.github/workflows/star-ranking.yml)
- PR 模板（中文）：[`.github/pull_request_template.zh-CN.md`](.github/pull_request_template.zh-CN.md)
- 策展策略（中文）：[`docs/CURATION_POLICY.zh-CN.md`](docs/CURATION_POLICY.zh-CN.md)
- 路线图（中文）：[`docs/ROADMAP.zh-CN.md`](docs/ROADMAP.zh-CN.md)
- Star 排行榜：[`docs/STAR_RANKING.zh-CN.md`](docs/STAR_RANKING.zh-CN.md)

## 分类

- [AI](categories/ai.zh-CN.md)
- [Frontend](categories/frontend.zh-CN.md)
- [Backend](categories/backend.zh-CN.md)
- [DevOps](categories/devops.zh-CN.md)
- [Security](categories/security.zh-CN.md)
- [Data](categories/data.zh-CN.md)
- [Mobile](categories/mobile.zh-CN.md)

## Star 排行榜

- [按 GitHub Star 排序的全局榜单](docs/STAR_RANKING.zh-CN.md)

## 收录标准

每个被收录的仓库应尽量满足以下条件：

- 仓库名以 `awesome` 开头（大小写不敏感）。
- 主题边界清晰（不是随意堆砌链接）。
- README 结构良好，条目组织清楚。
- 近期仍在维护（优先近 12 个月有更新）。
- 有一定价值信号：star、社区使用或专家策展。
- 快速信号：`Star >= 5,000` 的仓库优先收录。
- 垃圾内容和失效链接比例低。

## 条目格式

在分类文件中使用以下格式：

```md
- [owner/repo](https://github.com/owner/repo) - 一行简洁且有实际价值的描述。
```

## 贡献指南

提交前请先阅读 [`CONTRIBUTING.zh-CN.md`](CONTRIBUTING.zh-CN.md)。

## Star History

[![Star History Chart](https://api.star-history.com/svg?repos=your-github-username/awesome-awesome&type=Date)](https://star-history.com/#your-github-username/awesome-awesome&Date)

## 许可证

[MIT](LICENSE)
