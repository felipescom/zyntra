package main

import (
	"context"
	"fmt"
	"log"
	"os"
	"time"

	"github.com/felipescom/zyntra/backend/internal/platform/config"
	"github.com/felipescom/zyntra/backend/internal/platform/migrations"
	"github.com/felipescom/zyntra/backend/internal/platform/postgres"
)

func main() {
	cfg := config.Load()

	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Minute)
	defer cancel()

	db, err := postgres.Open(ctx, cfg.DatabaseURL, cfg.DBMaxOpenConn, cfg.DBMaxIdleConn)
	if err != nil {
		log.Fatalf("database connection failed: %v", err)
	}
	defer db.Close()

	applied, err := migrations.ApplyPending(ctx, db, cfg.MigrationsDir)
	if err != nil {
		log.Fatalf("migrations failed: %v", err)
	}

	_, _ = fmt.Fprintf(os.Stdout, "migrations applied: %d\n", applied)
}
