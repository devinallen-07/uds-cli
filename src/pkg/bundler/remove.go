// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: 2023-Present The UDS Authors

// Package bundler contains functions for interacting with, managing and deploying UDS packages
package bundler

import (
	"context"
	"github.com/defenseunicorns/zarf/src/pkg/packager"
	"github.com/defenseunicorns/zarf/src/pkg/utils"
	"github.com/defenseunicorns/zarf/src/types"
)

// Remove should do the same as previous code
//
// really this is prob just gonna loop over the packages and call `p.Remove()`
//
// should this support some form of `--components`?
func (b *Bundler) Remove() error {
	ctx := context.TODO()
	// create a new provider
	provider, err := NewBundleProvider(ctx, b.cfg.RemoveOpts.Source, b.tmp)
	if err != nil {
		return err
	}

	// pull the bundle's metadata + sig
	loaded, err := provider.LoadBundleMetadata()
	if err != nil {
		return err
	}

	// read the bundle's metadata into memory
	if err := utils.ReadYaml(loaded[BundleYAML], &b.bundle); err != nil {
		return err
	}

	for _, pkg := range b.bundle.ZarfPackages {
		name := pkg.Name
		pkgTmp, err := utils.MakeTempDir()
		if err != nil {
			return err
		}
		pkgCfg := types.PackagerConfig{
			PkgOpts: types.ZarfPackageOptions{
				PackagePath: name,
			},
		}
		pkgClient, err := packager.New(&pkgCfg)
		if err != nil {
			return err
		}
		if err := pkgClient.SetTempDirectory(pkgTmp); err != nil {
			return err
		}
		defer pkgClient.ClearTempPaths()

		if err := pkgClient.Remove(); err != nil {
			return err
		}
	}

	return nil
}
