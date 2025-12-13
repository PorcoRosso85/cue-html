package schema

import "strings"

// renderedPages is the main export target
renderedPages: [ for page in pages {
	path: page.path

	// Build HTML sections
	let sectionsHtml = [ for section in page.sections {
		let frag = fragments[section.fragmentId]
		"""
		<section id="\(section.id)">
		  <h\(section.level)>\(frag.title)</h\(section.level)>
		  \(frag.bodyHtml)
		</section>
		"""
	}]

	// Build complete HTML
	html: """
		<!DOCTYPE html>
		<html lang="ja">
		<head>
		  <meta charset="UTF-8">
		  <meta name="viewport" content="width=device-width, initial-scale=1.0">
		  <title>\(page.id)</title>
		  <script src="https://cdn.jsdelivr.net/npm/htmx.org@2.0.8/dist/htmx.min.js"
		          integrity="sha384-H96JQQqwZEPVeSN43+6YYj4yD+kVFo6yx4SvYwT5VjHWQ0Ty6eHYb8UJ1SHVVwjj"
		          crossorigin="anonymous"></script>
		</head>
		<body>
		\(strings.Join(sectionsHtml, "\n"))
		</body>
		</html>
		"""
}]
