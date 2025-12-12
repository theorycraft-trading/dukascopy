# Used by "mix format"
[
  import_deps: [:simple_enum],
  inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"],
  locals_without_parens: [
    assert_chronological_order: 1,
    assert_uniform_spacing: 2
  ]
]
