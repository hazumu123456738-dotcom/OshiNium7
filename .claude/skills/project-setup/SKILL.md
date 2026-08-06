---
name: project-setup
description: OshiNiumのiOS基盤(Xcodeプロジェクト構成)専任チェック。新規Swiftファイルを追加するとき、または project.pbxproj やディレクトリ構成に触れる作業をするときに必ず使う。Views/・Models /・Tabs/・Managers /・ViewModels/ がXcodeのfile-system-synchronizedグループではなく、xcodeproj gemでの手動登録が必要という罠の再発防止が目的。「新しいSwiftファイルを追加して」「ビルドがBuild input files cannot be foundで失敗する」のような場面で使う。
---

# project-setup — OshiNium iOS基盤(プロジェクト構成)専任チェック

このスキルは、新規Swiftファイルを追加する作業、またはXcodeプロジェクト構成(`project.pbxproj`、ディレクトリ構成)に触れる作業のたびに呼ぶ。目的は、このリポジトリ固有の「非同期グループ」の罠で無駄なビルド破壊を起こさないこと。

## 前提: どのディレクトリが同期グループで、どれが非同期か

`OshiNium7.xcodeproj`は`OshiNium7/`直下のみが**file-system-synchronizedグループ**(Xcode 16以降の機能。ディスク上にファイルを置くだけで自動的にプロジェクトへ反映される)。それ以外の主要ディレクトリ——`Views/` `Models /`(末尾スペース注意) `Tabs/` `Managers /`(末尾スペース注意) `ViewModels/`——は**すべて非同期グループ**であり、ディスク上にファイルを置くだけではXcodeプロジェクトに反映されない。ビルドには影響しない(ファイルが単に無視される)ため、「ファイルは作ったのにビルドに反映されない/実行時にクラッシュしない代わりに変更が全く効かない」という形で発覚しにくい失敗モードになる。

## 新規Swiftファイルを追加する手順

1. 通常通りWriteツールで対象ディレクトリ(`Views/`等)にファイルを作成する。
2. `xcodeproj` Rubyジェムで`project.pbxproj`に手動登録する:

```ruby
require 'xcodeproj'
project = Xcodeproj::Project.open('OshiNium7.xcodeproj')

target = project.targets.find { |t| t.name == 'OshiNium7' }
group = project.main_group.find_subpath('Views', false) # 対象グループ名に置き換える

# ★ 重要: ファイル名のみを渡す。グループが既に path を持っているため、
#   フルパス("Views/NewFile.swift")を渡すと "Views/Views/NewFile.swift" という
#   二重パスになり、ビルドが "Build input files cannot be found" で失敗する。
file_ref = group.new_reference('NewFile.swift')
target.add_file_references([file_ref])

project.save
```

3. `xcodebuild`でクリーンビルドし、対象ファイルが実際にコンパイル対象になっているか確認する(`Build input files cannot be found`エラーが出ないこと)。

## 既知の実害の痕跡

ルート直下に`AppDelegate.swift .swift`という壊れたファイル名(末尾スペース+二重拡張子)が実在していた。これはこの手動登録プロセスでの操作ミスの痕跡と見られる。同様のファイル名の乱れがないか、新規ファイル追加のたびに念のため`find . -name "* .swift"`で確認する習慣を持つ。

## ディレクトリ構成そのものを変更する場合(リネーム・同期グループ化)

- 末尾スペースの除去(`git mv "Models " Models`等)のような単純なリネームは、`git mv`実行後に`project.pbxproj`内の対応グループの`path`属性も手動で書き換える必要がある(`xcodeproj` gem、またはテキスト置換で該当箇所のみ)。リネーム後は必ずクリーンビルドで検証する。
- `Views/`等を丸ごとfile-system-synchronizedグループへ移行する作業は影響範囲が大きい(全ファイル参照の書き換えを伴う)。着手する場合は他の作業と並行させず、単独の1タスクとして完結させ、完了後に必ずクリーンビルド+`verify` Skillでの実機起動確認を行う。

## Worktreeとの関係

複数のWorktree/Sub Agentで同時に新規ファイル追加を伴う作業を走らせると、`project.pbxproj`(単一ファイル)への書き込みが競合しやすい。並行作業を行う場合は、少なくとも一方が`project.pbxproj`に触れない(既存ファイルの編集のみで完結する)タスクであることを確認する。
