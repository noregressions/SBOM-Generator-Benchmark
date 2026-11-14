// A small command that is honest about two of its four dependencies.
//
// go.mod requires four modules. Only two of them are compiled into the binary:
//
//	github.com/google/uuid   imported here                      -> linked
//	golang.org/x/text        imported here                      -> linked
//	gopkg.in/yaml.v3         imported only by main_test.go      -> never linked
//	github.com/dgrijalva/jwt-go  imported only by debug.go, which is built only with -tags debug -> not linked
package main

import (
	"fmt"
	"os"

	"github.com/google/uuid"
	"golang.org/x/text/language"
)

// greeting names the language a request asked for, falling back to English.
func greeting(tag string) string {
	t, err := language.Parse(tag)
	if err != nil {
		t = language.English
	}
	return fmt.Sprintf("language %s", t)
}

func main() {
	tag := "en-GB"
	if len(os.Args) > 1 {
		tag = os.Args[1]
	}
	fmt.Printf("request %s %s\n", uuid.NewString(), greeting(tag))
	debugDump()
}
