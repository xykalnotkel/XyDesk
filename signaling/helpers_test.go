package main

import (
	"io"
	"log"
)

func logNoop() *log.Logger {
	return log.New(io.Discard, "", 0)
}
