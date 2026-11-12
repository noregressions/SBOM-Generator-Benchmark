package main

import (
	"fmt"
	"net/http"

	"github.com/google/uuid"
	"github.com/gorilla/mux"
	"gopkg.in/yaml.v3"
)

func main() {
	r := mux.NewRouter()
	r.HandleFunc("/", func(w http.ResponseWriter, _ *http.Request) {
		out, _ := yaml.Marshal(map[string]string{"id": uuid.NewString(), "msg": "hello sbom"})
		fmt.Fprint(w, string(out))
	})
	http.ListenAndServe(":8080", r)
}
