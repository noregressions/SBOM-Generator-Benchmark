package main

import (
	"testing"

	"gopkg.in/yaml.v3"
)

// The cases are kept as YAML so that the test needs a YAML parser. Nothing outside the tests does.
const cases = `
- {tag: en-GB, want: language en-GB}
- {tag: fr, want: language fr}
- {tag: "not a tag", want: language en}
`

func TestGreeting(t *testing.T) {
	var table []struct{ Tag, Want string }
	if err := yaml.Unmarshal([]byte(cases), &table); err != nil {
		t.Fatal(err)
	}
	for _, c := range table {
		if got := greeting(c.Tag); got != c.Want {
			t.Errorf("greeting(%q) = %q, want %q", c.Tag, got, c.Want)
		}
	}
}
