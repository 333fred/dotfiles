; extends

((qualified_name
  (identifier) @module)
  (#has-ancestor? @module using_directive)
  (#set! @module priority 110))
