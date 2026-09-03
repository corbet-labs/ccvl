set shell := ["bash", "-euo", "pipefail", "-c"]

default:
    @just --list

doctor:
    bash ./ccvl doctor

check:
    bash ./ccvl check

profile-status *args:
    bash ./ccvl profile-status {{args}}

measure *args:
    bash ./ccvl measure {{args}}

measure-opportunity organisation-key position-key:
    bash ./ccvl measure-opportunity "{{organisation-key}}" "{{position-key}}"

public-check:
    bash ./ccvl public-check

build:
    bash ./ccvl build

new-opportunity organisation-key position-key:
    bash ./ccvl new-opportunity "{{organisation-key}}" "{{position-key}}"

build-cv locale pages="4" application="" profile="":
    scripts/render.sh cv "{{locale}}" "{{pages}}" "{{application}}" "{{profile}}"

build-cl locale application="" profile="":
    scripts/render.sh cl "{{locale}}" "{{application}}" "{{profile}}"

build-opportunity organisation-key position-key:
    bash ./ccvl build-opportunity "{{organisation-key}}" "{{position-key}}"

watch-cv locale pages="4":
    typst watch --root . --font-path cvl/shared/fonts --ignore-system-fonts --input "cv-pages={{pages}}" "cvl/cv/{{locale}}/main.typ" "cvl/cv/output/{{locale}}/{{pages}}pager/cv.pdf"

fmt:
    typstyle --inplace --line-width 120 cvl
