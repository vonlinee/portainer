package embedded

import (
	"embed"
	"io/fs"
)

// Public contains the frontend static assets for embedded binary deployments.
//
//go:embed public
var Public embed.FS

// PublicFS returns the embedded frontend assets rooted at the public directory.
func PublicFS() fs.FS {
	publicFS, err := fs.Sub(Public, "public")
	if err != nil {
		panic(err)
	}

	return publicFS
}
