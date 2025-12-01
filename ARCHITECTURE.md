# CUE-HTML Architecture - 責務と契約 v2

> **注意**: このドキュメントは実装フェーズのアーキテクチャ定義です。実装完了後は削除予定です。

## v1→v2 変更点
- ❌ `schema/htmx.cue` 削除（htmx CDN は render/common.cue に直接埋め込み）
- ❌ `render/commands.cue` 削除（Makefile に統合）
- ❌ `scripts/print-html.sh` 削除（Go版のみに集中）

## 1. レイヤー構造

```
┌─────────────────────────────────────────────────────────────┐
│                    Content Layer (値)                        │
│  content/fragments/*.cue, content/pages/*.cue               │
│  [責務] 実際のコンテンツを定義（HTML文字列、ページ構造）      │
└─────────────────────────────────────────────────────────────┘
                            ↓ uses
┌─────────────────────────────────────────────────────────────┐
│                    Schema Layer (型)                         │
│  schema/model.cue, schema/validation.cue                    │
│  [責務] 型定義と制約ルールの提供                              │
└─────────────────────────────────────────────────────────────┘
                            ↓ validates
┌─────────────────────────────────────────────────────────────┐
│                   Render Layer (変換)                        │
│  render/print-html.cue, render/layout.cue, render/export.cue│
│  [責務] Fragment/Section/Page → HTML文字列への変換          │
└─────────────────────────────────────────────────────────────┘
                            ↓ produces
┌─────────────────────────────────────────────────────────────┐
│              Export Layer (JSON生成)                         │
│  render/export.cue                                          │
│  [責務] renderedPages 構造の定義、export可能な形式に整形     │
└─────────────────────────────────────────────────────────────┘
                            ↓ exported by
┌─────────────────────────────────────────────────────────────┐
│                  Build Layer (実行)                          │
│  Makefile                                                   │
│  [責務] cue export 実行、プリンタ呼び出し、クリーンアップ     │
└─────────────────────────────────────────────────────────────┘
                            ↓ calls
┌─────────────────────────────────────────────────────────────┐
│                  Printer Layer (出力)                        │
│  cmd/html-printer/main.go                                   │
│  [責務] JSON → ファイルシステムへの書き出しのみ               │
└─────────────────────────────────────────────────────────────┘
                            ↓ writes
┌─────────────────────────────────────────────────────────────┐
│                     Output (成果物)                          │
│  out/**/*.html                                              │
│  [成果物] 完全なcanonical HTML（SEO対応、htmx対応）         │
└─────────────────────────────────────────────────────────────┘
```

---

## 2. 各ファイルの詳細責務

### 2.1 Schema Layer

#### `schema/model.cue`

**責務**:
- `#Fragment` 型の定義
  - `id: string` - 一意識別子
  - `title: string` - 見出しテキスト
  - `bodyHtml: string` - 正規化されたHTML本文（h*タグなし）
- `#Section` 型の定義
  - `id: string` - セクション識別子
  - `level: 1 | 2 | 3` - 見出しレベル
  - `parentId?: string` - 親セクションへの参照（任意）
  - `fragmentId: string` - 使用するフラグメントのID
- `#Page` 型の定義
  - `id: string` - ページ識別子
  - `kind: "docs" | "article" | "lp"` - ページ種別
  - `path: string` - URL パス（例: `/docs/intro`）
  - `sections: [...#Section]` - セクションリスト
  - `canonical?: string` - canonical URL（任意）
  - `indexPolicy?: "index" | "noindex"` - SEO indexing ポリシー

**契約**:
- 型定義の破壊的変更は禁止（後方互換性を保つ）
- 新フィールド追加は任意（`?`）で行う

#### `schema/validation.cue`

**責務**:
- `#Page.path` の重複禁止チェック
- `#Section.fragmentId` が `#Fragment.id` に存在することの検証
- 1ページ内の `level=1` が最大1つであることの検証
- `level` の飛び級（1→3）禁止
- `#Section.parentId` が存在する場合、既存セクションを指すことの検証

**契約**:
- `cue vet ./...` で全検証が実行可能
- エラーメッセージは具体的（どのページ・セクションが違反しているか明示）

**削除**: `schema/htmx.cue` は v1 では作成しません
- htmx CDN の `<script>` タグは `render/common.cue` に直接埋め込み
- hx-get 等の動的属性は Phase 7（将来）で実装時に schema/htmx.cue を追加

---

### 2.2 Render Layer

#### `render/common.cue`

**責務**:
- `<head>` タグの生成
  - `<meta charset="UTF-8">`
  - `<meta name="viewport" ...>`
  - **htmx CDN script タグ**（v1では直接埋め込み）
    - 例: `<script src="https://cdn.jsdelivr.net/npm/htmx.org@2.0.8/dist/htmx.min.js" integrity="..." crossorigin="anonymous"></script>`
  - canonical link（ページごとに動的）
- `<footer>` タグの生成
- 共通 CSS（インライン or 外部リンク）

**契約**:
- `headHtml(page: #Page) -> string` 関数を提供
- `footerHtml() -> string` 関数を提供
- htmx バージョンアップ時はこのファイルの `<script>` タグを更新

#### `render/layout.cue`

**責務**:
- `kind` による HTML構造の分岐
  - `"docs"` → サイドバー付きレイアウト
  - `"article"` → 記事レイアウト（breadcrumb等）
  - `"lp"` → LP用ヘッダー・CTA
- レイアウトごとの wrapper HTML 生成

**契約**:
- `layoutHtml(page: #Page, contentHtml: string) -> string` 関数を提供
- contentHtml（本文）を受け取り、レイアウトでラップして返す

#### `render/print-html.cue`

**責務**:
- **Section → HTML 変換**
  - `level` に応じて `<h1>` / `<h2>` / `<h3>` を決定
  - `fragmentId` から `#Fragment` を引いて `title` / `bodyHtml` を取得
  - `<section id="..."><h*>title</h*>bodyHtml</section>` を生成
- **Page → sectionsHtml 配列生成**
  - `page.sections` をループして各 section の HTML を生成
  - `sectionsHtml: [...string]` に格納
- **renderedPages 生成**
  - 全ページをループ
  - `{ path: page.path, html: fullPageHtml }` の配列を出力
  - `fullPageHtml = layoutHtml(page, join(sectionsHtml, "\n"))`

**契約**:
- `render.renderedPages` という名前で export される
- 構造: `[{ path: string, html: string }, ...]`
- `html` は `<!DOCTYPE html>` から始まる完全なHTML

#### `render/export.cue`

**責務**:
- `renderedPages` 構造の定義
  - `[{ path: string, html: string }, ...]` の形式
- export 可能な形に整形
  - `cue export -e render.renderedPages` で取得可能にする

**契約**:
- `render.renderedPages` という名前で export される
- この段階ではファイル出力はしない（JSON構造の定義のみ）

---

### 2.3 Build Layer

#### `Makefile`

**責務**:
- `ssg` ターゲットの定義
- 実行フロー:
  1. `cue export -e render.renderedPages > tmp/renderedPages.json`
  2. `go run ./cmd/html-printer tmp/renderedPages.json ./out`
  3. `rm tmp/renderedPages.json`（クリーンアップ）

**契約**:
- `make ssg` で HTML 生成が完結
- CUE と Go の橋渡し役
- エラーハンドリング（cue export 失敗時は printer を呼ばない）

---

### 2.4 Content Layer

#### `content/fragments/common.cue`

**責務**:
- docs/articles/LP 共通で使える汎用フラグメント定義
- 例:
  - `frag-intro`: サービス紹介
  - `frag-cta`: CTA文言
  - `frag-privacy`: プライバシーポリシー要約

**契約**:
- `fragments: { [id: string]: #Fragment }`
- 各フラグメントは `schema/model.cue` の `#Fragment` 型に準拠

#### `content/fragments/docs.cue`

**責務**:
- docs 専用のフラグメント定義
- 例:
  - `frag-docs-overview`: docsトップの概要
  - `frag-api-reference`: API仕様

**契約**:
- `common.cue` と同じ構造

#### `content/pages/docs.cue`

**責務**:
- `/docs/**` のページ定義
- 例:
  ```cue
  pages: [{
    id: "docs-intro"
    kind: "docs"
    path: "/docs/intro"
    sections: [
      { id: "s1", level: 1, fragmentId: "frag-docs-overview" },
      { id: "s2", level: 2, fragmentId: "frag-api-reference", parentId: "s1" }
    ]
  }]
  ```

**契約**:
- `pages: [...#Page]`
- 全ページが `schema/validation.cue` の制約を満たす

#### `content/pages/articles.cue`

**責務**:
- `/articles/**` のページ定義

**契約**:
- `docs.cue` と同じ

#### `content/pages/lp.cue`

**責務**:
- `/solo/**` pSEO LP のページ定義

**契約**:
- `docs.cue` と同じ

---

### 2.5 Printer Layer

#### `cmd/html-printer/main.go`

**責務**:
- **JSON読み込み**
  - `tmp/renderedPages.json` を読む
  - `[]struct { Path string, Html string }` にデコード
- **ファイル書き出し**
  - `path` → `outDir + path + "/index.html"` に変換
  - ディレクトリが存在しなければ作成（`os.MkdirAll`）
  - `html` をそのまま書き込む
- **エラーハンドリング**
  - JSON parse エラー → exit 1
  - ファイル書き込みエラー → exit 1

**契約**:
- コマンドライン引数: `html-printer <jsonPath> <outDir>`
- 終了コード: 0（成功）, 1（失敗）
- **テンプレートロジックは一切持たない**（単なる書き出し器）

**削除**: `scripts/print-html.sh` は v1 では実装しません
- Go版のみに集中（将来の拡張性を考慮）
- 必要になったら後で追加可能

---

### 2.6 Test Layer

#### `tests/validation_test.cue`

**責務**:
- **異常系テスト**: わざと制約違反のデータを作成
  - path重複エラー
  - fragmentId不在エラー
  - level飛び級エラー
  - 複数H1エラー
- `cue vet` を実行して「エラーが出ること」を確認

**役割の明確化**:
- 正常系: `schema/validation.cue` の制約定義
- 異常系: `tests/validation_test.cue` でエラー発火テスト

**契約**:
- `cue vet ./tests/validation_test.cue` で実行
- 異常系は意図的にエラーになることを確認

#### `tests/snapshot_test.sh`

**責務**:
- 生成HTMLと期待値の diff 検証
- 手順:
  1. `cue cmd ssg` を実行
  2. `out/docs/example/index.html` と `tests/snapshots/docs_example.html` を diff
  3. 差分があれば exit 1

**契約**:
- 終了コード: 0（一致）, 1（差分あり）

#### `tests/htmx_check.sh`

**責務**:
- 全HTMLファイルに htmx CDN が含まれるかチェック
- 手順:
  1. `find out/ -name "*.html"` で全HTML取得
  2. 各ファイルで `grep -q "htmx.org"`（**バージョン非依存**）
  3. 含まれないファイルがあれば exit 1

**バージョン非依存の理由**:
- htmx のバージョンアップ時にテストが壊れないようにする
- `@2.0.8` のようなバージョン番号は見ない

**契約**:
- 終了コード: 0（全て含む）, 1（未含あり）

---

## 3. データフロー図

```
[content/fragments/*.cue]
        ↓ defines
[Fragment値集合] ←────────┐
        ↓                 │
[content/pages/*.cue]      │
        ↓ uses            │
[Page値集合]              │
        ↓                 │
[render/print-html.cue]   │
        ↓ references ─────┘
[renderedPages JSON]
        ↓
[cue export]
        ↓
[tmp/renderedPages.json]
        ↓
[cmd/html-printer]
        ↓
[out/**/*.html]
```

---

## 4. 依存関係マトリックス

| Layer | 依存先 | 依存理由 |
|-------|--------|---------|
| Content | Schema | 型定義に準拠 |
| Render | Schema, Content | 型定義を使い、コンテンツ値を変換 |
| Export | Render | renderedPages 構造を定義 |
| Build (Makefile) | Export, Printer | cue export を実行し、Printer を呼び出す |
| Printer | - | JSON を受け取るのみ（他レイヤーに依存しない） |
| Test | Schema, Render, Printer | バリデーション・出力検証 |

**循環依存禁止**: Schema → Content → Render → Export → Build → Printer の一方向のみ

**v1→v2 変更点**:
- Command Layer（render/commands.cue）を Build Layer（Makefile）に置き換え
- Printer は JSON のみを受け取る純粋な出力器（他レイヤーへの依存なし）

---

## 5. 拡張ポイント

### 5.1 新しいページ種別追加（例: "landing-page-v2"）

**変更箇所**:
1. `schema/model.cue`: `kind` に `"landing-page-v2"` 追加
2. `render/layout.cue`: 新レイアウト関数追加
3. `content/pages/lp-v2.cue`: 新規作成

**変更不要**:
- Printer（JSON構造は同じ）
- Test（自動的に検証対象になる）

### 5.2 htmx 動的差し替え機能追加（Phase 7）

**変更箇所**:
1. `schema/htmx.cue`: **新規作成** - `#Section` に `hxGet?`, `hxTarget?` フィールド追加
2. `schema/model.cue`: `#Section` を `schema/htmx.cue` の型を使うように変更
3. `render/print-html.cue`: `hxGet` が存在する場合 `hx-get` 属性を付与
4. `tests/htmx_check.sh`: `hx-get` 属性の検証追加

**変更不要**:
- Printer（HTML文字列は変わるが、JSON構造は同じ）
- Makefile（ビルドフローは変わらない）

### 5.3 マルチサイト対応

**変更箇所**:
1. `schema/model.cue`: `#Page` に `siteId: string` 追加
2. `render/commands.cue`: サイトごとに JSON 分割
3. `cmd/html-printer`: サイトごとに出力先ディレクトリ変更

---

## 6. トレードオフの明示

### 6.1 CUE vs Go の責務分担

**採用案**: CUE = 型+データ+変換ロジック, Go = 出力のみ

**トレードオフ**:
- ✅ メリット: テンプレートロジックが一元化
- ✅ メリット: CUE でのバリデーションが強力
- ❌ デメリット: CUE の文字列操作が冗長になる可能性
- ❌ デメリット: 大量ページ（1000+）では CUE が遅い可能性

**代替案**: Go に変換ロジックも持たせる（html/template 等）
- ✅ メリット: Go の方が文字列操作が楽
- ❌ デメリット: 型とテンプレートが分離し、密結合が弱まる

**結論**: 当面は CUE に寄せる。パフォーマンス問題が出たら Go 移行を検討。

### 6.2 Go vs sh プリンタ

**採用案**: Go版のみ実装

**トレードオフ**:
- ✅ メリット: 将来の拡張（minify, 差分出力）が楽
- ✅ メリット: 依存ツールが少ない（jq不要）
- ❌ デメリット: Go コードの保守が必要

**代替案**: sh + jq
- ✅ メリット: 実装が超簡単
- ❌ デメリット: 複雑なロジック追加が困難

**結論（v2）**: Go版のみ実装。sh版は v1 では作成しない（必要になったら後で追加）。

### 6.3 スナップショットテストの粒度

**採用案**: 3ファイルのみ（docs/article/lp 各1つ）

**トレードオフ**:
- ✅ メリット: 保守コストが低い
- ❌ デメリット: 全パターンを網羅できない

**代替案**: 全ページをスナップショット化
- ✅ メリット: 完全な差分検出
- ❌ デメリット: 保守コストが高すぎる

**結論**: 最小限に留める。重要な変更は手動確認。

---

## 7. セキュリティ考慮事項

### 7.1 XSS 対策

**リスク**: `bodyHtml` に `<script>` タグが混入

**対策**:
1. `bodyHtml` は **信頼できるコンテンツのみ** とする（UGC禁止）
2. 将来UGCを扱う場合は、別レイヤーでサニタイズ
3. CUE のバリデーションで `<script>` タグ検出（オプション）

### 7.2 Path Traversal

**リスク**: `path: "../../etc/passwd"` のような悪意ある値

**対策**:
1. Printer側で path を正規化（`filepath.Clean`）
2. `outDir` の外に書き込まないことを保証
3. CUE のバリデーションで `path` の形式チェック（`/[a-z0-9/-]+`）

---

## 8. パフォーマンス考慮事項

### 8.1 CUE の評価速度

**想定**: 100ページ程度なら問題なし（< 1秒）

**懸念**: 1000+ ページでは遅延の可能性

**対策**:
- Phase 6 後にベンチマーク実施
- 遅い場合は Go側で並列化検討

### 8.2 ファイル書き込み

**想定**: 並列書き込みで高速化可能

**対策**:
- Go版で goroutine 使用（将来拡張）

---

この Architecture ドキュメントは PLAN.md と合わせて、プロジェクトの全体像を提供します。
