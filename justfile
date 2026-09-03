set shell := ["bash", "-euo", "pipefail", "-c"]

default:
    @just --list

doctor:
    scripts/doctor.sh

check:
    scripts/check.sh

public-check:
    scripts/public-check.sh

build:
    scripts/render.sh all

build-cv locale pages="4" application="" profile="":
    scripts/render.sh cv "{{locale}}" "{{pages}}" "{{application}}" "{{profile}}"

build-cl locale application="" profile="":
    scripts/render.sh cl "{{locale}}" "{{application}}" "{{profile}}"

build-application application locale pages="4" profile="":
    scripts/render.sh application "{{application}}" "{{locale}}" "{{pages}}" "{{profile}}"

watch-cv locale pages="4":
    typst watch --root . --font-path cvl/shared/fonts --ignore-system-fonts --input "cv-pages={{pages}}" "cvl/cv/{{locale}}/main.typ" "out/watch-cv-{{locale}}-{{pages}}.pdf"

fmt:
    typstyle --inplace --line-width 120 cvl showcase
