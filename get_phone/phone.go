package main

import (
	"net/http"
	"os"
	"io/ioutil"
	"log"
)

func handler(w http.ResponseWriter, r *http.Request) {
	if (r.Method == "POST") {
		body, err := ioutil.ReadAll(r.Body)
		file := "." + r.URL.Path

		log.Printf("'%s' > %s\n", string(body), file)
		fd, err := os.OpenFile(file, os.O_TRUNC | os.O_CREATE | os.O_WRONLY, 0644)
		if err != nil {
			panic(err)
		}
		if err != nil {
			panic(err)
		}
		fd.Write(body)
		fd.Close()
		r.Body.Close()
	} else {
		log.Printf("Method: %s %s without any handler\n", r.Method, r.URL.Path)
	}
}

func main() {
	port := os.Getenv("PHONE_PORT")
	if port == "" {
		port = "8080"
	}

	listen := "0.0.0.0:" + port

	cwd, _ := os.Getwd()

	http.HandleFunc("/", handler)
	log.Printf("listen and serve: http://%s write file in: %v\n",
		listen, cwd)
	err := http.ListenAndServe(listen, nil)
	if err != nil {
		log.Fatalf("fail to serve %s\n", listen)
	} else {
		log.Println("stop serving")
	}
}