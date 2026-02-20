package config

import (
	"os"
	"strconv"
	"time"
)

type Config struct {
	Environment   string
	HTTPAddr      string
	DatabaseURL   string
	MigrationsDir string
	ReadTimeout   time.Duration
	WriteTimeout  time.Duration
	IdleTimeout   time.Duration
	DBMaxOpenConn int
	DBMaxIdleConn int
}

func Load() Config {
	return Config{
		Environment:   getenv("APP_ENV", "development"),
		HTTPAddr:      getenv("HTTP_ADDR", ":8080"),
		DatabaseURL:   getenv("DATABASE_URL", "postgres://postgres:postgres@localhost:5432/zyntra?sslmode=disable"),
		MigrationsDir: getenv("MIGRATIONS_DIR", "migrations"),
		ReadTimeout:   getDuration("HTTP_READ_TIMEOUT", 10*time.Second),
		WriteTimeout:  getDuration("HTTP_WRITE_TIMEOUT", 15*time.Second),
		IdleTimeout:   getDuration("HTTP_IDLE_TIMEOUT", 60*time.Second),
		DBMaxOpenConn: getInt("DB_MAX_OPEN_CONNS", 25),
		DBMaxIdleConn: getInt("DB_MAX_IDLE_CONNS", 25),
	}
}

func getenv(key string, fallback string) string {
	if value, ok := os.LookupEnv(key); ok && value != "" {
		return value
	}

	return fallback
}

func getInt(key string, fallback int) int {
	value, ok := os.LookupEnv(key)
	if !ok || value == "" {
		return fallback
	}

	parsed, err := strconv.Atoi(value)
	if err != nil {
		return fallback
	}

	return parsed
}

func getDuration(key string, fallback time.Duration) time.Duration {
	value, ok := os.LookupEnv(key)
	if !ok || value == "" {
		return fallback
	}

	parsed, err := time.ParseDuration(value)
	if err != nil {
		return fallback
	}

	return parsed
}
