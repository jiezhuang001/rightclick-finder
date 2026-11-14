-- 用 iWork 导出三个空白 Office 模板，替代手写的最小 OOXML。
-- 输出目录通过 argv 传入（必须是真实用户目录下的路径）。
on run argv
	set outDir to item 1 of argv

	-- 1) Pages -> Word.docx
	tell application "Pages"
		activate
		set newDoc to make new document
		set outFile to (outDir & "/Word.docx") as POSIX file
		export newDoc to outFile as Microsoft Word
		close newDoc saving no
	end tell

	-- 2) Numbers -> Excel.xlsx
	tell application "Numbers"
		activate
		set newDoc to make new document
		set outFile to (outDir & "/Excel.xlsx") as POSIX file
		export newDoc to outFile as Microsoft Excel
		close newDoc saving no
	end tell

	-- 3) Keynote -> PPT.pptx
	tell application "Keynote"
		activate
		set newDoc to make new document
		set outFile to (outDir & "/PPT.pptx") as POSIX file
		export newDoc to outFile as Microsoft PowerPoint
		close newDoc saving no
	end tell

	return "done"
end run
