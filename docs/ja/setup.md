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

<a id="redmine-kits-new-ui"></a>

## Redmine Kit の新しい UI

[Redmine Kit UI](https://github.com/redmine-kit/redmine_kit_ui) をインストールすると、このプラグインはその拡張 API
(`init.rb` の `kit_ui`。設定は不要です) で新しい UI でも動きます:

- **新しいチケット** は、新しい UI のフォームのステップとしてテンプレートの選択画面を表示し、選んだテンプレートを
  フォームの先頭に表示します: テンプレートの説明、テンプレートが設定する値、フォームの入力欄です。ルールは Redmine の
  フォームと同じで (非表示、設定済み、リンク、必須の項目。説明に書く回答。`config.yml` のとおりの空白のチケット)、
  サーバーでプラグインが決めます。
- **プロジェクトの設定 › チケットテンプレート** は、ファイルとその状態を一覧し、リポジトリからインポートし、
  テンプレートの選択画面の設定を保存します。新しいファイルや編集するファイルはファイルのフォームを開きます。
- 新しい UI にはまだないもの: フォームのアップロード欄 (欄にその旨を表示します。Redmine の画面にはあります) と、
  ファイルのページのプレビュー。

新しい UI のモジュールは `assets/javascripts/kit/issue_template.js` で、`frontend/` (React と TypeScript) から
ビルドします: `cd frontend && npm ci && npm run check` で型チェック、ビルド、`bin/check-ui` を実行します。ビルドした
ファイルはソースと一緒にコミットします。

<a id="tests"></a>

## テスト

`bin/test` は、コンテナ ([Apple container](https://github.com/apple/container) がインストールされて動いていればそれ、なければ Docker。`CONTAINER_CLI=container` または `CONTAINER_CLI=docker` で選べます) の中の Redmine 7.0.3 と PostgreSQL 16 で、プラグインのテストを実行します。続けて、プラグインをインストールした状態で、Redmine のチケットの入力画面、プロジェクトの設定、Git リポジトリのテストを実行します。`bin/test --redmine` は、Redmine のすべてのテストを実行します。GitHub のドキュメントの例は `test/fixtures/github/` にあり、そのままの形でテストします。

```sh
bin/test
bin/test --redmine
REDMINE_BRANCH=master bin/test   # Redmine の master ブランチで実行
bin/services --down              # PostgreSQL を止める
bin/lint                         # RuboCop と Brakeman (同じコンテナのツールで)
bin/screenshots                  # ドキュメントのスクリーンショット(docs/images/、docs/ja/images/)
```

`bin/screenshots` (今は Docker だけ) は、Redmine のテストのデータと GitHub の例を使い、ヘッドレスの Chromium でスクリーンショットを撮ります(`test/screenshots/screens.rb`)。画面を変えたら実行します。

<a id="to-verify"></a>

## 未確認の事項

- Subversion、Mercurial など、Git 以外の SCM に置いたテンプレート(テストは Git で行っています)。
- 大きなリポジトリでの所要時間。取り込みは、リポジトリを取得するたびにテンプレートフォルダーを読みます。
