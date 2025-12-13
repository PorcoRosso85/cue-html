package schema

// Sample pages for testing
pages: [
	{
		id:   "docs-intro"
		kind: "docs"
		path: "/docs/intro"
		sections: [
			{id: "s1", level: 1, fragmentId: "intro"},
			{id: "s2", level: 2, fragmentId: "features"},
			{id: "s3", level: 2, fragmentId: "getting-started"},
		]
	},
	{
		id:   "article-sample"
		kind: "article"
		path: "/articles/sample"
		sections: [
			{id: "a1", level: 1, fragmentId: "article-intro"},
			{id: "a2", level: 2, fragmentId: "article-body"},
		]
	},
	{
		id:   "lp-main"
		kind: "lp"
		path: "/solo/main"
		sections: [
			{id: "l1", level: 1, fragmentId: "lp-hero"},
			{id: "l2", level: 2, fragmentId: "lp-cta"},
		]
	},
]
