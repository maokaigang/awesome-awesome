# Awesome Awesome

> A curated index of truly awesome `awesome-xxx` repositories.

[![Awesome](https://awesome.re/badge.svg)](https://awesome.re)
[![中文 README](https://img.shields.io/badge/README-%E4%B8%AD%E6%96%87-blue)](README.zh-CN.md)

`awesome-awesome` focuses on high-quality, actively maintained `awesome-xxx` lists and resource hubs.

## Why this repo

There are thousands of `awesome-xxx` repos. This project helps you:

- Discover trustworthy, active, and practical awesome lists faster.
- Navigate by topic instead of searching randomly.
- Track quality with simple contribution and validation rules.

## Quick Start

- Browse categories in [`categories/`](categories/).
- Read inclusion rules in [`CONTRIBUTING.md`](CONTRIBUTING.md).
- Open a PR with your suggested repo.

## Governance

- Validation script: [`scripts/validate.sh`](scripts/validate.sh)
- Selection policy validator: [`scripts/validate-selection.sh`](scripts/validate-selection.sh)
- Link check script: [`scripts/check-links.sh`](scripts/check-links.sh)
- Star ranking script: [`scripts/generate-star-ranking.sh`](scripts/generate-star-ranking.sh)
- CI workflow: [`.github/workflows/validate.yml`](.github/workflows/validate.yml)
- Scheduled link check workflow: [`.github/workflows/link-check.yml`](.github/workflows/link-check.yml)
- Scheduled star ranking workflow: [`.github/workflows/star-ranking.yml`](.github/workflows/star-ranking.yml)
- PR template: [`.github/pull_request_template.md`](.github/pull_request_template.md)
- Curation policy: [`docs/CURATION_POLICY.md`](docs/CURATION_POLICY.md)
- Roadmap: [`docs/ROADMAP.md`](docs/ROADMAP.md)
- Star ranking: [`docs/STAR_RANKING.md`](docs/STAR_RANKING.md)

## Categories

- [AI](categories/ai.md)
- [Frontend](categories/frontend.md)
- [Backend](categories/backend.md)
- [DevOps](categories/devops.md)
- [Security](categories/security.md)
- [Data](categories/data.md)
- [Mobile](categories/mobile.md)

## Star Ranking

- [Global ranking by GitHub stars](docs/STAR_RANKING.md)

## Selection Criteria

Each listed repo should satisfy most of these:

- Repository name starts with `awesome` (case-insensitive).
- Clear topic scope (not a random dump).
- Good README structure and tagging.
- Recently maintained (prefer updates in the last 12 months).
- Useful signal: stars, community usage, or expert curation.
- Fast-track signal: repositories with `>= 5,000` stars are preferred for inclusion.
- Low spam ratio and broken link ratio.

## Entry Format

Use this format in category files:

```md
- [owner/repo](https://github.com/owner/repo) - One-line practical description.
```

## Contributing

Please read [`CONTRIBUTING.md`](CONTRIBUTING.md) before submitting changes.

## Star History

[![Star History Chart](https://api.star-history.com/svg?repos=maokaigang/awesome-awesome&type=Date)](https://star-history.com/#maokaigang/awesome-awesome&Date)

## License

[MIT](LICENSE)
