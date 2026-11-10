# Redmine Issue Template

[![CI](https://img.shields.io/github/actions/workflow/status/redmine-kit/redmine_issue_template/ci.yml?branch=main&label=CI)](https://github.com/redmine-kit/redmine_issue_template/actions/workflows/ci.yml)
[![Coverage](https://img.shields.io/codecov/c/github/redmine-kit/redmine_issue_template?label=Coverage)](https://codecov.io/gh/redmine-kit/redmine_issue_template)
[![License](https://img.shields.io/github/license/redmine-kit/redmine_issue_template?label=License)](LICENSE)

Redmine Issue Template(`redmine_issue_template`)は、チケットテンプレートの Redmine プラグインです。「新しいチケット」を押すとテンプレート選択画面が開き、選んだテンプレートがチケットの入力画面を埋めます。テンプレートファイルはプロジェクトのリポジトリの `.redmine/ISSUE_TEMPLATE/` に置き、リポジトリが変わると Redmine が取り込みます。`.github/ISSUE_TEMPLATE/` のファイルも、そのまま読めます。

[English](README.md)

> **状態:** 開発の初期です。

- Markdown テンプレート、YAML フォーム、選択画面の設定の `config.yml` を使います。トラッカー、優先度、カテゴリ、対象バージョン、カスタムフィールドも、同じファイルに書きます。
- テンプレートごとに、チケットの入力欄を隠したり、必須にしたりできます。
- リポジトリが変わると、Redmine がテンプレートを取り込みます。リポジトリのないプロジェクトは、プロジェクトの設定で編集します。[Redmine GitHub](https://github.com/redmine-kit/redmine_github) で、GitHub のリポジトリから取り込むこともできます。

## ドキュメント

- Web サイト: https://redmine-kit.github.io/redmine_issue_template/ja/ (English: https://redmine-kit.github.io/redmine_issue_template/)
- Markdown: [docs/ja/README.md](docs/ja/README.md) (English: [docs/README.md](docs/README.md))

<a id="sponsors"></a>

## スポンサー

<a href="https://www.keyselect.co.jp/">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset=".github/assets/keyselect-logo-dark.svg">
    <img alt="KEY SELECT" src=".github/assets/keyselect-logo.svg" width="136" height="29">
  </picture>
</a>

<a id="license"></a>

## ライセンス

Redmine Issue Template は、GNU General Public License バージョン 2 またはそれ以降のバージョンで公開しています。[LICENSE](LICENSE) を参照してください。Redmine の非公式のプラグインです。
