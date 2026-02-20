package migrations

import (
	"context"
	"database/sql"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"time"
)

const ensureSchemaMigrations = `
CREATE TABLE IF NOT EXISTS schema_migrations (
	version TEXT PRIMARY KEY,
	applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);`

type Migration struct {
	Version string
	Path    string
}

func ApplyPending(ctx context.Context, db *sql.DB, migrationsDir string) (int, error) {
	if err := ensureMigrationsTable(ctx, db); err != nil {
		return 0, err
	}

	migrations, err := loadMigrations(migrationsDir)
	if err != nil {
		return 0, err
	}

	applied, err := listAppliedMigrations(ctx, db)
	if err != nil {
		return 0, err
	}

	appliedCount := 0
	for _, migration := range migrations {
		if _, exists := applied[migration.Version]; exists {
			continue
		}

		if err := applyMigration(ctx, db, migration); err != nil {
			return appliedCount, err
		}

		appliedCount++
	}

	return appliedCount, nil
}

func ensureMigrationsTable(ctx context.Context, db *sql.DB) error {
	if _, err := db.ExecContext(ctx, ensureSchemaMigrations); err != nil {
		return fmt.Errorf("ensure schema_migrations: %w", err)
	}

	return nil
}

func loadMigrations(migrationsDir string) ([]Migration, error) {
	entries, err := os.ReadDir(migrationsDir)
	if err != nil {
		return nil, fmt.Errorf("read migrations dir %q: %w", migrationsDir, err)
	}

	migrations := make([]Migration, 0)
	for _, entry := range entries {
		if entry.IsDir() {
			continue
		}

		name := entry.Name()
		if filepath.Ext(name) != ".sql" || !strings.HasSuffix(name, ".up.sql") {
			continue
		}

		version := strings.TrimSuffix(name, ".up.sql")
		if version == "" {
			continue
		}

		migrations = append(migrations, Migration{
			Version: version,
			Path:    filepath.Join(migrationsDir, name),
		})
	}

	sort.Slice(migrations, func(i, j int) bool {
		return migrations[i].Version < migrations[j].Version
	})

	return migrations, nil
}

func listAppliedMigrations(ctx context.Context, db *sql.DB) (map[string]struct{}, error) {
	rows, err := db.QueryContext(ctx, `SELECT version FROM schema_migrations`)
	if err != nil {
		return nil, fmt.Errorf("query schema_migrations: %w", err)
	}
	defer rows.Close()

	applied := make(map[string]struct{})
	for rows.Next() {
		var version string
		if err := rows.Scan(&version); err != nil {
			return nil, fmt.Errorf("scan schema_migrations version: %w", err)
		}

		applied[version] = struct{}{}
	}

	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate schema_migrations: %w", err)
	}

	return applied, nil
}

func applyMigration(ctx context.Context, db *sql.DB, migration Migration) error {
	sqlBytes, err := os.ReadFile(migration.Path)
	if err != nil {
		return fmt.Errorf("read migration %s: %w", migration.Version, err)
	}

	tx, err := db.BeginTx(ctx, nil)
	if err != nil {
		return fmt.Errorf("begin tx %s: %w", migration.Version, err)
	}

	defer func() {
		if err != nil {
			_ = tx.Rollback()
		}
	}()

	execCtx, cancel := context.WithTimeout(ctx, 30*time.Second)
	defer cancel()

	if _, err = tx.ExecContext(execCtx, string(sqlBytes)); err != nil {
		return fmt.Errorf("exec migration %s: %w", migration.Version, err)
	}

	if _, err = tx.ExecContext(ctx, `INSERT INTO schema_migrations (version, applied_at) VALUES ($1, NOW())`, migration.Version); err != nil {
		return fmt.Errorf("record migration %s: %w", migration.Version, err)
	}

	if err = tx.Commit(); err != nil {
		return fmt.Errorf("commit migration %s: %w", migration.Version, err)
	}

	return nil
}

func LoadFromFS(source fs.FS, root string) ([]Migration, error) {
	entries, err := fs.ReadDir(source, root)
	if err != nil {
		return nil, err
	}

	migrations := make([]Migration, 0, len(entries))
	for _, entry := range entries {
		if entry.IsDir() {
			continue
		}

		name := entry.Name()
		if filepath.Ext(name) != ".sql" || !strings.HasSuffix(name, ".up.sql") {
			continue
		}

		version := strings.TrimSuffix(name, ".up.sql")
		migrations = append(migrations, Migration{
			Version: version,
			Path:    filepath.Join(root, name),
		})
	}

	sort.Slice(migrations, func(i, j int) bool {
		return migrations[i].Version < migrations[j].Version
	})

	return migrations, nil
}
