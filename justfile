# https://just.systems/man/en/

publish:
  mix hex.publish

outdated:
  mix hex.outdated

remove-unused-deps:
  mix deps.clean --unused 
  mix deps.clean --unlock --unused