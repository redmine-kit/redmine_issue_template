# 導入

<a id="requirements"></a>

## 動作環境

- Redmine 7.0 以降。
- Redmine のテキスト書式が CommonMark Markdown であること(管理 › 設定 › 全般)。テンプレートと YAML フォームの回答は Markdown なので、Textile では説明が意図どおりに表示されません。
- テンプレートをリポジトリに置く場合は、Redmine が読めるプロジェクトのリポジトリ(Git、または Redmine が対応するほかの SCM)。

<a id="installation"></a>

## インストール

プラグインを `plugins/redmine_issue_template` に置き、マイグレーションを実行して、Redmine を再起動します。マイグレーションは、`issue_template_files` と `issue_template_sources` の 2 つのテーブルを作ります。

```sh
bin/rake redmine:plugins:migrate
```

<a id="gem"></a>

### gem

バージョンのタグ(`v*`)ごとに、プラグインを gem として GitHub Packages(`https://rubygems.pkg.github.com/redmine-kit`)に公開します。GitHub Packages からのインストールには、公開のパッケージでも `read:packages` の権限を持つ GitHub のトークンが要ります。Redmine は `plugins/` からしかプラグインを読まないので、インストールした gem をそこにリンクします。

```ruby
# Redmine の Gemfile.local
source 'https://rubygems.pkg.github.com/redmine-kit' do
  gem 'redmine_issue_template'
end
```

```sh
bundle config set --global rubygems.pkg.github.com <ユーザー>:<トークン>   # または BUNDLE_RUBYGEMS__PKG__GITHUB__COM
bundle install
ln -s "$(bundle info --path redmine_issue_template)" plugins/redmine_issue_template
```

<a id="without-the-gem"></a>

### gem を使わないとき

リポジトリを `plugins/redmine_issue_template` にクローンします。ほかの gem は要りません。

```sh
git clone https://github.com/redmine-kit/redmine_issue_template.git plugins/redmine_issue_template
```

<a id="configuration"></a>

## 設定

プロジェクトの設定で、モジュール「チケットテンプレート」を有効にします(新しいプロジェクトのデフォルトは、管理 › 設定 › プロジェクト で決めます)。テンプレートを管理するロールには、権限「チケットテンプレートの管理」を与えます。この権限で、プロジェクトの設定の「チケットテンプレート」タブ、「インポート」のボタン、ファイルの編集が使えます。選択画面を使うだけなら、「チケットの追加」の権限で足ります。

そのうえで、リポジトリにテンプレートを置いてリポジトリを取得するか([テンプレートの形式](format.md))、プロジェクトの設定でファイルを追加します([取り込みと同期](sync.md))。

<a id="tests"></a>

## テスト

`bin/test` は、Docker の中の Redmine 7.0.3 と PostgreSQL 16 で、プラグインのテストを実行します。続けて、プラグインをインストールした状態で、Redmine のチケットの入力画面、プロジェクトの設定、Git リポジトリのテストを実行します。`bin/test --redmine` は、Redmine のすべてのテストを実行します。GitHub のドキュメントの例は `test/fixtures/github/` にあり、そのままの形でテストします。

```sh
bin/test
bin/test --redmine
REDMINE_BRANCH=master bin/test   # Redmine の master ブランチで実行
bin/services --down              # PostgreSQL を止める
bin/lint                         # RuboCop and Brakeman
bin/screenshots                  # ドキュメントのスクリーンショット(docs/images/、docs/ja/images/)
```

`bin/screenshots` は、Redmine のテストのデータと GitHub の例を使い、ヘッドレスの Chromium でスクリーンショットを撮ります(`test/screenshots/screens.rb`)。画面を変えたら実行します。

<a id="to-verify"></a>

## 未確認の事項

- Subversion、Mercurial など、Git 以外の SCM に置いたテンプレート(テストは Git で行っています)。
- 大きなリポジトリでの所要時間。取り込みは、リポジトリを取得するたびにテンプレートフォルダーを読みます。
