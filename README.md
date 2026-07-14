# Beej's Guide to Network Programming（日本語版）

[Beej's Guide to Network Programming](https://beej.us/guide/bgnet/) の非公式日本語訳です。

- **公開サイト**: https://sashi0034.github.io/bgnet-ja/
- **原文**: https://beej.us/guide/bgnet/
- **原文ソース**: https://github.com/beejjorgensen/bgnet
- **著者**: Brian “Beej Jorgensen” Hall

ライセンスは Creative Commons Attribution-NonCommercial-NoDerivatives 3.0 です（翻訳はライセンス上許可されています）。C のサンプルコードはパブリックドメインです。

## 読む

ビルド済みの HTML は GitHub Pages で公開しています。分割 HTML がおすすめです。

## ビルド（HTML のみ）

依存:

- [Gnu make](https://www.gnu.org/software/make/)
- [Python 3+](https://www.python.org/)
- [Pandoc 2.7.3+](https://pandoc.org/)
- ビルドシステム [bgbspd](https://github.com/beejjorgensen/bgbspd)（このリポジトリの sibling として clone）

```text
parent/
  bgnet-ja/     # このリポジトリ
  bgbspd/       # https://github.com/beejjorgensen/bgbspd
```

```bash
# Linux / macOS / Git Bash など
export BGBSPD_BUILD_DIR=../bgbspd
./scripts/build-html-stage.sh
# → _site/ に GitHub Pages 向け HTML が出力されます
```

PDF を含むフルビルドが必要な場合は、原文 README と同様に `make all` / `make stage`（XeLaTeX が必要）または Docker を使ってください。本フォークの公開対象は HTML のみです。

## 翻訳について

本文のソースは `src/bgnet_part_*.md` です。和訳するときは Beej 独自の Markdown 拡張（`[i[...]]`、`[fl[...]]`、`{#anchor}` など）を壊さないでください。詳細は `src/README.md` を参照。

## GitHub Pages

`main` への push で `.github/workflows/pages.yml` が HTML をビルドし、GitHub Pages にデプロイします。

リポジトリ設定で **Settings → Pages → Source = GitHub Actions** を有効にしてください。
