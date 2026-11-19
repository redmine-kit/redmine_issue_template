# 導入

<a id="requirements"></a>

## 動作環境

- Redmine 7.0 以降。
- Redmine のテキスト書式が CommonMark Markdown であること(管理 › 設定 › 全般)。テンプレートと YAML フォームの回答は Markdown なので、Textile では説明が意図どおりに表示されません。
- テンプレートをリポジトリに置く場合は、Redmine が読めるプロジェクトのリポジトリ(Git、または Redmine が対応するほかの SCM)。

<a id="installation"></a>

## インストール

プラグインを `plugins/redmine_kit_issue_template` に置き、マイグレーションを実行して、Redmine を再起動します。マイグレーションは、`issue_template_files` と `issue_template_sources` の 2 つのテーブルを作ります。

```sh
bin/rake redmine:plugins:migrate
```

<a id="gem"></a>

### gem

バージョンのタグ(`v*`)ごとに、プラグインを gem として GitHub Packages(`https://rubygems.pkg.github.com/redmine-kit`)に公開します。GitHub Packages からのインストールには、公開のパッケージでも `read:packages` の権限を持つ GitHub のトークンが要ります。Redmine は `plugins/` からしかプラグインを読まないので、インストールした gem をそこにリンクします。

```ruby
# Redmine の Gemfile.local
source 'https://rubygems.pkg.github.com/redmine-kit' do
  gem 'redmine_kit_issue_template'
end
```

```sh
bundle config set --global rubygems.pkg.github.com <ユーザー>:<トークン>   # または BUNDLE_RUBYGEMS__PKG__GITHUB__COM
bundle install
ln -s "$(bundle info --path redmine_kit_issue_template)" plugins/redmine_kit_issue_template
```

<a id="without-the-gem"></a>

### gem を使わないとき

リポジトリを `plugins/redmine_kit_issue_template` にクローンします。ほかの gem は要りません。

```sh
git clone https://github.com/redmine-kit/redmine_issue_template.git plugins/redmine_kit_issue_template
```

<a id="configuration"></a>

## 設定

プロジェクトの設定で、モジュール「チケットテンプレート」を有効にします(新しいプロジェクトのデフォルトは、管理 › 設定 › プロジェクト で決めます)。テンプレートを管理するロールには、権限「チケットテンプレートの管理」を与えます。この権限で、プロジェクトの設定の「チケットテンプレート」タブ、「インポート」のボタン、ファイルの編集が使えます。選択画面を使うだけなら、「チケットの追加」の権限で足ります。

そのうえで、リポジトリにテンプレートを置いてリポジトリを取得するか([テンプレートの形式](format.md))、プロジェクトの設定でファイルを追加します([取り込みと同期](sync.md))。

<a id="redmine-kits-new-ui"></a>

## Redmine Kit の新しい UI

[Redmine Kit UI](https://github.com/redmine-kit/redmine_kit_ui) をインストールすると、このプラグインはその拡張 API
(`init.rb` の `kit_ui`。設定は不要です) で新しい UI でも動きます:

- **新しいチケット** は、新しい UI のフォームのステップとしてテンプレートの選択画面を表示します。選んだテンプレートは
  フォームの先頭 (名前の前に選択画面に戻る ‹、その後に説明) に、フォームの入力欄は題名の後、説明の位置に表示します。
  テキストエリアはコンパクトな Markdown エディター (`render` があるときは、回答をコードブロックとして記録すると注記した
  通常のテキストエリア)、`multiple` のドロップダウンは複数選択のリスト、`link` の入力欄には設定するチケットの項目を
  注記します。テンプレートが設定する値は、その項目の位置に読み取り専用 (読み取り専用 (テンプレート)) で表示し、
  フォームではチケットのほかの項目を そのほかの項目 に要約付きで折りたたみます (必須の項目は折りたたみません)。
  作成 はフォームの必須の回答を待ち、最初の 1 件を表示します。作成 をクリックすると各項目のメッセージを表示します。
  テンプレートに入力した内容はフォームを開いている間は残ります。戻ると選択画面で 入力中 と表示し、もう一度選ぶと続きから
  入力できます。ページのサイドバーには、テンプレートの取得元 (テンプレートのファイル)、テンプレートで非表示の項目、
  チケットテンプレートを管理できるユーザーには 設定 › チケットテンプレート へのリンクを表示します。
  ルールは Redmine のフォームと同じで (非表示、設定済み、リンク、必須の項目。説明に書く回答。`config.yml` のとおりの
  空白のチケット)、サーバーでプラグインが決めます。
- **アップロードの欄** は新しい UI 自身のファイルの欄です。新しい UI が Redmine の制限 (サイズ、拡張子、欄の `accept`)
  でファイルをアップロードして Redmine 自身の uploads で送り、フォームは添付ファイルの ID で指します。サーバーは、
  そのリクエストのファイルのうちユーザーがアップロードしたものだけを受け取ります。
- **プロジェクトの設定 › チケットテンプレート** は 2 つのペインです: ファイルとその状態 (エラー、警告) と
  テンプレートの選択画面 (`config.yml`)、そして選んだファイルの 編集 と 削除、メッセージ、プレビュー (ユーザーが見る
  選択画面の行と、そのテンプレートでの新しいチケットのフォーム)、内容、`config.yml` では 設定 (空白のチケットと
  その他の連絡先)。取得元 はファイルの取得元 (リポジトリのフォルダー、リビジョン、日時、またはプロジェクトの設定で編集して
  いるときは プロジェクトの設定) を示し、ファイルのメッセージには エラー または 警告 の見出しが付きます。設定 には
  空白のチケットを許可 の説明と、保存すると `config.yml` を作り直す旨の注記があります。ヘッダーに ヘルプ、インポート
  (リポジトリがあるとき。ツールチップで今すぐフォルダーを読み込むことを示します)、新しいテンプレート があります。新しいファイルと
  編集 はファイルのフォームをドロワーで開き、入力中のテキストを プレビュー できます。フォームの URL
  (`/projects/<id>/issue_templates/new`、`…/<ファイル>/edit`) を開くと、同じフォームを設定のタブの横のページで、
  形式のヘルプ と一緒に表示します。

新しい UI のモジュールは `assets/javascripts/kit/issue_template.js` で、`frontend/` (React と TypeScript) から
ビルドします。`bin/setup` が、このリポジトリの隣の ui-mock のチェックアウトで、ビルドに使うアプリのパッケージ
(`@redmine-kit/ui`、`@redmine-kit/plugin`) をビルドし、フロントエンドのパッケージをインストールします。そのあと
`cd frontend && npm run check` で型チェック、テスト (`npm test`。Vitest と Testing Library、`@redmine-kit/plugin/testing`)、ビルド、`kit-check-ui` を実行します。ビルドしたファイルはソースと一緒に
コミットします。

<a id="tests"></a>

## テスト

`bin/test` は、コンテナ ([Apple container](https://github.com/apple/container) がインストールされて動いていればそれ、なければ Docker。`CONTAINER_CLI=container` または `CONTAINER_CLI=docker` で選べます) の中の Redmine 7.0.3 と PostgreSQL 16 で、プラグインのテストを実行します。続けて、プラグインをインストールした状態で、Redmine のチケットの入力画面、プロジェクトの設定、Git リポジトリのテストを実行します。`bin/test --redmine` は、Redmine のすべてのテストを実行します。GitHub のドキュメントの例は `test/fixtures/github/` にあり、そのままの形でテストします。

```sh
bin/test
bin/test --redmine
REDMINE_BRANCH=master bin/test   # Redmine の master ブランチで実行
COVERAGE=1 bin/test              # プラグインのカバレッジも (coverage/coverage.xml)
bin/services --down              # PostgreSQL を止める
bin/lint                         # RuboCop と Brakeman (同じコンテナのツールで)
bin/screenshots                  # ドキュメントのスクリーンショット(docs/images/、docs/ja/images/)
```

`COVERAGE=1 bin/test` は、テストによるプラグインのファイルのカバレッジも [SimpleCov](https://github.com/simplecov-ruby/simplecov) で測り、Cobertura XML として `coverage/coverage.xml` に書き出します。1 ワーカーで実行するため、時間が長くかかります。CI は Redmine 7.0.3 でこれを実行し、ファイルを GitHub の OIDC トークンで [Codecov](https://app.codecov.io/gh/redmine-kit/redmine_issue_template) にアップロードします。Codecov のトークンは使いません (`.github/workflows/ci.yml`、`codecov.yml`)。

`bin/screenshots` (今は Docker だけ) は、Redmine のテストのデータと GitHub の例を使い、ヘッドレスの Chromium でスクリーンショットを撮ります(`test/screenshots/screens.rb`)。画面を変えたら実行します。

<a id="to-verify"></a>

## 未確認の事項

- Subversion、Mercurial など、Git 以外の SCM に置いたテンプレート(テストは Git で行っています)。
- 大きなリポジトリでの所要時間。取り込みは、リポジトリを取得するたびにテンプレートフォルダーを読みます。
