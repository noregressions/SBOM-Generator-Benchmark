#!/usr/bin/env bash
. "$(dirname "$0")/../../criteria/adapter-lib.sh"
# cyclonedx-gomod: Go test cases. It has three modes and the benchmark uses all of them.
#   app  the modules an application's main package needs (its documented mode for applications)  -> cyclonedx-gomod.cdx.json
#   mod  the module's requirements, whether or not anything links them                            -> cyclonedx-gomod-mod.cdx.json
#   bin  the modules recorded inside a built binary                                               -> cyclonedx-gomod.cdx.json (artefact stage)
need cyclonedx-gomod
if [[ "$EV_STAGE" == source ]]; then
  dir=$(ex .stages.source.go); [[ -n "$dir" ]] || na
  main=$(ex .stages.source.go_main); rc=0
  # It runs in the real tree, like the other build tools: `app` refuses to work outside a git repository, because it
  # takes the main module's version from the commit. Defaults are kept, so the standard library is not listed (-std).
  if [[ -n "$main" ]]; then
    cyclonedx-gomod app -json -main "$main" -output "$EV_OUT/cyclonedx-gomod.cdx.json" "$EV_PROJECT/$dir" || rc=$?
  fi
  cyclonedx-gomod mod -json -output "$EV_OUT/cyclonedx-gomod-mod.cdx.json" "$EV_PROJECT/$dir" || rc=$?
  exit $rc
elif [[ "$EV_KIND" == binary ]]; then
  cyclonedx-gomod bin -json -output "$EV_OUT/cyclonedx-gomod.cdx.json" "$EV_INPUT"
else na; fi
