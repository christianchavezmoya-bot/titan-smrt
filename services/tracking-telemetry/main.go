// Tracking Telemetry Service - Go
// Handles: GPS, Heart Rate, Rep Counting, IoT Sync, Session Aggregation
// Uses: TimescaleDB for time-series data, Kafka for event streaming

package main

import (
	"encoding/json"
	"log"
	"net/http"
	"time"

	"github.com/gorilla/mux"
	"github.com/jmoiron/sqlx"
	_ "github.com/lib/pq"
)

// Time-series data structures
type GPSPoint struct {
	SessionID  string    `json:"session_id" db:"session_id"`
	UserID     string    `json:"user_id" db:"user_id"`
	Timestamp  time.Time `json:"timestamp" db:"timestamp"`
	Latitude   float64   `json:"latitude" db:"latitude"`
	Longitude  float64   `json:"longitude" db:"longitude"`
	Altitude   float64   `json:"altitude" db:"altitude"`
	Speed      float64   `json:"speed" db:"speed"`
	Accuracy   float64   `json:"accuracy" db:"accuracy"`
}

type HeartRateReading struct {
	SessionID  string    `json:"session_id" db:"session_id"`
	UserID     string    `json:"user_id" db:"user_id"`
	Timestamp  time.Time `json:"timestamp" db:"timestamp"`
	BPM        int       `json:"bpm" db:"bpm"`
	Source     string    `json:"source" db:"source"` // BLE, Apple Watch, Garmin
	HRV        float64   `json:"hrv" db:"hrv"`       // Heart Rate Variability
}

type RepEvent struct {
	SessionID   string    `json:"session_id" db:"session_id"`
	UserID      string    `json:"user_id" db:"user_id"`
	ExerciseID  string    `json:"exercise_id" db:"exercise_id"`
	Timestamp   time.Time `json:"timestamp" db:"timestamp"`
	RepCount    int       `json:"rep_count" db:"rep_count"`
	Weight      float64   `json:"weight" db:"weight"`
	FormScore   float64   `json:"form_score" db:"form_score"`
	DetectedBy  string    `json:"detected_by" db:"detected_by"` // AI, Manual, Wearable
}

type WorkoutSession struct {
	ID           string    `json:"id" db:"id"`
	UserID       string    `json:"user_id" db:"user_id"`
	StartTime    time.Time `json:"start_time" db:"start_time"`
	EndTime      time.Time `json:"end_time" db:"end_time"`
	WorkoutType  string    `json:"workout_type" db:"workout_type"` // strength, cardio, hybrid
	TotalVolume  float64   `json:"total_volume" db:"total_volume"`
	TotalReps    int       `json:"total_reps" db:"total_reps"`
	AvgHR        int       `json:"avg_hr" db:"avg_hr"`
	MaxHR        int       `json:"max_hr" db:"max_hr"`
	Calories     int       `json:"calories" db:"calories"`
	Distance     float64   `json:"distance" db:"distance"` // km
	Status       string    `json:"status" db:"status"` // active, completed, abandoned
}

type TelemetryBatch struct {
	SessionID    string          `json:"session_id"`
	UserID       string          `json:"user_id"`
	GPSPoints    []GPSPoint      `json:"gps_points"`
	HeartRates   []HeartRateReading `json:"heart_rates"`
	RepEvents    []RepEvent      `json:"rep_events"`
	ClientTime   time.Time       `json:"client_time"`
}

type TelemetryService struct {
	db     *sqlx.DB
	kafka  *KafkaProducer
}

type KafkaProducer struct {
	// TODO: Add Kafka producer client
}

func main() {
	db, err := sqlx.Connect("postgres", getDBConnString())
	if err != nil {
		log.Fatalf("Failed to connect to TimescaleDB: %v", err)
	}
	defer db.Close()

	// Initialize hypertables for time-series data
	initHypertables(db)

	service := &TelemetryService{
		db: db,
		kafka: &KafkaProducer{},
	}

	r := mux.NewRouter()
	
	// Telemetry endpoints
	r.HandleFunc("/api/v1/telemetry/gps", service.LogGPS).Methods("POST")
	r.HandleFunc("/api/v1/telemetry/heart-rate", service.LogHeartRate).Methods("POST")
	r.HandleFunc("/api/v1/telemetry/reps", service.LogReps).Methods("POST")
	r.HandleFunc("/api/v1/telemetry/batch", service.LogBatch).Methods("POST")
	
	// Session management
	r.HandleFunc("/api/v1/telemetry/sessions", service.StartSession).Methods("POST")
	r.HandleFunc("/api/v1/telemetry/sessions/{id}/end", service.EndSession).Methods("POST")
	r.HandleFunc("/api/v1/telemetry/sessions/{id}", service.GetSession).Methods("GET")
	r.HandleFunc("/api/v1/telemetry/sessions/{id}/summary", service.GetSessionSummary).Methods("GET")
	
	// Analytics endpoints
	r.HandleFunc("/api/v1/telemetry/users/{user_id}/stats", service.GetUserStats).Methods("GET")
	r.HandleFunc("/api/v1/telemetry/users/{user_id}/history", service.GetWorkoutHistory).Methods("GET")
	
	// Real-time WebSocket endpoint
	r.HandleFunc("/ws/telemetry/{session_id}", service.WebSocketHandler)
	
	// Health check
	r.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		json.NewEncoder(w).Encode(map[string]string{"status": "ok", "service": "tracking-telemetry"})
	}).Methods("GET")

	log.Println("Tracking Telemetry Service starting on :8081")
	log.Fatal(http.ListenAndServe(":8081", r))
}

func initHypertables(db *sqlx.DB) {
	// Create tables
	queries := []string{
		`CREATE TABLE IF NOT EXISTS gps_points (
			session_id UUID NOT NULL,
			user_id UUID NOT NULL,
			timestamp TIMESTAMPTZ NOT NULL,
			latitude DOUBLE PRECISION,
			longitude DOUBLE PRECISION,
			altitude DOUBLE PRECISION,
			speed DOUBLE PRECISION,
			accuracy DOUBLE PRECISION
		)`,
		`CREATE TABLE IF NOT EXISTS heart_rate_readings (
			session_id UUID NOT NULL,
			user_id UUID NOT NULL,
			timestamp TIMESTAMPTZ NOT NULL,
			bpm INTEGER,
			source VARCHAR(50),
			hrv DOUBLE PRECISION
		)`,
		`CREATE TABLE IF NOT EXISTS rep_events (
			session_id UUID NOT NULL,
			user_id UUID NOT NULL,
			exercise_id UUID,
			timestamp TIMESTAMPTZ NOT NULL,
			rep_count INTEGER,
			weight DOUBLE PRECISION,
			form_score DOUBLE PRECISION,
			detected_by VARCHAR(50)
		)`,
		`CREATE TABLE IF NOT EXISTS workout_sessions (
			id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
			user_id UUID NOT NULL,
			start_time TIMESTAMPTZ NOT NULL,
			end_time TIMESTAMPTZ,
			workout_type VARCHAR(50),
			total_volume DOUBLE PRECISION DEFAULT 0,
			total_reps INTEGER DEFAULT 0,
			avg_hr INTEGER,
			max_hr INTEGER,
			calories INTEGER DEFAULT 0,
			distance DOUBLE PRECISION DEFAULT 0,
			status VARCHAR(20) DEFAULT 'active'
		)`,
	}
	
	for _, q := range queries {
		db.Exec(q)
	}
	
	// Create hypertables for time-series data (TimescaleDB)
	db.Exec(`SELECT create_hypertable('gps_points', 'timestamp', if_not_exists => TRUE)`)
	db.Exec(`SELECT create_hypertable('heart_rate_readings', 'timestamp', if_not_exists => TRUE)`)
	db.Exec(`SELECT create_hypertable('rep_events', 'timestamp', if_not_exists => TRUE)`)
	
	// Create indexes for fast queries
	db.Exec(`CREATE INDEX IF NOT EXISTS idx_gps_session ON gps_points (session_id, timestamp DESC)`)
	db.Exec(`CREATE INDEX IF NOT EXISTS idx_hr_session ON heart_rate_readings (session_id, timestamp DESC)`)
	db.Exec(`CREATE INDEX IF NOT EXISTS idx_rep_session ON rep_events (session_id, timestamp DESC)`)
}

func (s *TelemetryService) LogGPS(w http.ResponseWriter, r *http.Request) {
	var points []GPSPoint
	if err := json.NewDecoder(r.Body).Decode(&points); err != nil {
		http.Error(w, "Invalid request body", http.StatusBadRequest)
		return
	}
	
	// Batch insert into TimescaleDB
	tx := s.db.MustBegin()
	for _, p := range points {
		tx.NamedExec(
			`INSERT INTO gps_points (session_id, user_id, timestamp, latitude, longitude, altitude, speed, accuracy)
			 VALUES (:session_id, :user_id, :timestamp, :latitude, :longitude, :altitude, :speed, :accuracy)`,
			&p,
		)
	}
	tx.Commit()
	
	// Publish to Kafka
	// s.kafka.Publish("telemetry.gps", points)
	
	w.WriteHeader(http.StatusAccepted)
	json.NewEncoder(w).Encode(map[string]int{"inserted": len(points)})
}

func (s *TelemetryService) LogHeartRate(w http.ResponseWriter, r *http.Request) {
	var readings []HeartRateReading
	if err := json.NewDecoder(r.Body).Decode(&readings); err != nil {
		http.Error(w, "Invalid request body", http.StatusBadRequest)
		return
	}
	
	tx := s.db.MustBegin()
	for _, hr := range readings {
		tx.NamedExec(
			`INSERT INTO heart_rate_readings (session_id, user_id, timestamp, bpm, source, hrv)
			 VALUES (:session_id, :user_id, :timestamp, :bpm, :source, :hrv)`,
			&hr,
		)
	}
	tx.Commit()
	
	// Publish to Kafka for real-time processing
	// s.kafka.Publish("telemetry.heart-rate", readings)
	
	w.WriteHeader(http.StatusAccepted)
	json.NewEncoder(w).Encode(map[string]int{"inserted": len(readings)})
}

func (s *TelemetryService) LogReps(w http.ResponseWriter, r *http.Request) {
	var events []RepEvent
	if err := json.NewDecoder(r.Body).Decode(&events); err != nil {
		http.Error(w, "Invalid request body", http.StatusBadRequest)
		return
	}
	
	tx := s.db.MustBegin()
	for _, rep := range events {
		tx.NamedExec(
			`INSERT INTO rep_events (session_id, user_id, exercise_id, timestamp, rep_count, weight, form_score, detected_by)
			 VALUES (:session_id, :user_id, :exercise_id, :timestamp, :rep_count, :weight, :form_score, :detected_by)`,
			&rep,
		)
	}
	tx.Commit()
	
	// Publish to Kafka for AI processing
	// s.kafka.Publish("telemetry.reps", events)
	
	w.WriteHeader(http.StatusAccepted)
	json.NewEncoder(w).Encode(map[string]int{"inserted": len(events)})
}

func (s *TelemetryService) LogBatch(w http.ResponseWriter, r *http.Request) {
	var batch TelemetryBatch
	if err := json.NewDecoder(r.Body).Decode(&batch); err != nil {
		http.Error(w, "Invalid request body", http.StatusBadRequest)
		return
	}
	
	tx := s.db.MustBegin()
	
	// Insert GPS points
	for _, p := range batch.GPSPoints {
		p.SessionID = batch.SessionID
		p.UserID = batch.UserID
		tx.NamedExec(
			`INSERT INTO gps_points (session_id, user_id, timestamp, latitude, longitude, altitude, speed, accuracy)
			 VALUES (:session_id, :user_id, :timestamp, :latitude, :longitude, :altitude, :speed, :accuracy)`,
			&p,
		)
	}
	
	// Insert heart rate readings
	for _, hr := range batch.HeartRates {
		hr.SessionID = batch.SessionID
		hr.UserID = batch.UserID
		tx.NamedExec(
			`INSERT INTO heart_rate_readings (session_id, user_id, timestamp, bpm, source, hrv)
			 VALUES (:session_id, :user_id, :timestamp, :bpm, :source, :hrv)`,
			&hr,
		)
	}
	
	// Insert rep events
	for _, rep := range batch.RepEvents {
		rep.SessionID = batch.SessionID
		rep.UserID = batch.UserID
		tx.NamedExec(
			`INSERT INTO rep_events (session_id, user_id, exercise_id, timestamp, rep_count, weight, form_score, detected_by)
			 VALUES (:session_id, :user_id, :exercise_id, :timestamp, :rep_count, :weight, :form_score, :detected_by)`,
			&rep,
		)
	}
	
	tx.Commit()
	
	// Publish batch event to Kafka
	// s.kafka.Publish("telemetry.batch", batch)
	
	w.WriteHeader(http.StatusAccepted)
	json.NewEncoder(w).Encode(map[string]interface{}{
		"status": "accepted",
		"gps_points": len(batch.GPSPoints),
		"heart_rates": len(batch.HeartRates),
		"rep_events": len(batch.RepEvents),
	})
}

func (s *TelemetryService) StartSession(w http.ResponseWriter, r *http.Request) {
	var req struct {
		UserID      string `json:"user_id"`
		WorkoutType string `json:"workout_type"`
	}
	
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Invalid request body", http.StatusBadRequest)
		return
	}
	
	session := WorkoutSession{
		UserID:      req.UserID,
		StartTime:   time.Now(),
		WorkoutType: req.WorkoutType,
		Status:      "active",
	}
	
	// Insert session
	err := s.db.QueryRowx(
		`INSERT INTO workout_sessions (user_id, start_time, workout_type, status)
		 VALUES ($1, $2, $3, $4) RETURNING id`,
		session.UserID, session.StartTime, session.WorkoutType, session.Status,
	).Scan(&session.ID)
	
	if err != nil {
		http.Error(w, "Failed to create session", http.StatusInternalServerError)
		return
	}
	
	// Publish event to Kafka
	// s.kafka.Publish("workout.started", session)
	
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(session)
}

func (s *TelemetryService) EndSession(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	sessionID := vars["id"]
	
	// Calculate session summary
	var summary struct {
		TotalVolume float64
		TotalReps   int
		AvgHR       int
		MaxHR       int
		Calories    int
		Distance    float64
	}
	
	// Aggregate rep data
	s.db.Get(&summary.TotalVolume,
		`SELECT COALESCE(SUM(weight * rep_count), 0) FROM rep_events WHERE session_id = $1`, sessionID)
	s.db.Get(&summary.TotalReps,
		`SELECT COALESCE(SUM(rep_count), 0) FROM rep_events WHERE session_id = $1`, sessionID)
	
	// Aggregate heart rate data
	s.db.Get(&summary.AvgHR,
		`SELECT COALESCE(AVG(bpm)::int, 0) FROM heart_rate_readings WHERE session_id = $1`, sessionID)
	s.db.Get(&summary.MaxHR,
		`SELECT COALESCE(MAX(bpm), 0) FROM heart_rate_readings WHERE session_id = $1`, sessionID)
	
	// Calculate distance from GPS
	s.db.Get(&summary.Distance,
		`SELECT COALESCE(
			ST_Length(ST_MakeLine(ST_Point(longitude, latitude) ORDER BY timestamp)::geography) / 1000,
			0
		) FROM gps_points WHERE session_id = $1`, sessionID)
	
	// Estimate calories (simplified: calories = avg_hr * duration_minutes * 0.1)
	var durationMinutes float64
	s.db.Get(&durationMinutes,
		`SELECT EXTRACT(EPOCH FROM (NOW() - start_time)) / 60 FROM workout_sessions WHERE id = $1`, sessionID)
	summary.Calories = int(float64(summary.AvgHR) * durationMinutes * 0.1)
	
	// Update session
	s.db.Exec(
		`UPDATE workout_sessions 
		 SET end_time = NOW(), status = 'completed', 
		     total_volume = $2, total_reps = $3, avg_hr = $4, max_hr = $5, calories = $6, distance = $7
		 WHERE id = $1`,
		sessionID, summary.TotalVolume, summary.TotalReps, summary.AvgHR, summary.MaxHR, summary.Calories, summary.Distance,
	)
	
	// Publish event to Kafka
	// s.kafka.Publish("workout.completed", map[string]interface{}{
	// 	"session_id": sessionID,
	// 	"summary": summary,
	// })
	
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"session_id": sessionID,
		"status":     "completed",
		"summary":    summary,
	})
}

func (s *TelemetryService) GetSession(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	sessionID := vars["id"]
	
	var session WorkoutSession
	err := s.db.Get(&session, `SELECT * FROM workout_sessions WHERE id = $1`, sessionID)
	if err != nil {
		http.Error(w, "Session not found", http.StatusNotFound)
		return
	}
	
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(session)
}

func (s *TelemetryService) GetSessionSummary(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	sessionID := vars["id"]
	
	// Get session details
	var session WorkoutSession
	s.db.Get(&session, `SELECT * FROM workout_sessions WHERE id = $1`, sessionID)
	
	// Get heart rate timeline
	var hrTimeline []HeartRateReading
	s.db.Select(&hrTimeline,
		`SELECT * FROM heart_rate_readings WHERE session_id = $1 ORDER BY timestamp`, sessionID)
	
	// Get GPS path
	var gpsPath []GPSPoint
	s.db.Select(&gpsPath,
		`SELECT * FROM gps_points WHERE session_id = $1 ORDER BY timestamp`, sessionID)
	
	// Get rep breakdown
	var repBreakdown []RepEvent
	s.db.Select(&repBreakdown,
		`SELECT * FROM rep_events WHERE session_id = $1 ORDER BY timestamp`, sessionID)
	
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"session":       session,
		"hr_timeline":   hrTimeline,
		"gps_path":      gpsPath,
		"rep_breakdown": repBreakdown,
	})
}

func (s *TelemetryService) GetUserStats(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	userID := vars["user_id"]
	
	var stats struct {
		TotalWorkouts    int
		TotalVolume      float64
		TotalReps        int
		TotalCalories    int
		TotalDistance    float64
		AvgWorkoutLength float64
		BestStreak       int
	}
	
	s.db.Get(&stats.TotalWorkouts,
		`SELECT COUNT(*) FROM workout_sessions WHERE user_id = $1 AND status = 'completed'`, userID)
	s.db.Get(&stats.TotalVolume,
		`SELECT COALESCE(SUM(total_volume), 0) FROM workout_sessions WHERE user_id = $1`, userID)
	s.db.Get(&stats.TotalCalories,
		`SELECT COALESCE(SUM(calories), 0) FROM workout_sessions WHERE user_id = $1`, userID)
	s.db.Get(&stats.TotalDistance,
		`SELECT COALESCE(SUM(distance), 0) FROM workout_sessions WHERE user_id = $1`, userID)
	
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(stats)
}

func (s *TelemetryService) GetWorkoutHistory(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	userID := vars["user_id"]
	
	var sessions []WorkoutSession
	s.db.Select(&sessions,
		`SELECT * FROM workout_sessions WHERE user_id = $1 ORDER BY start_time DESC LIMIT 50`, userID)
	
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(sessions)
}

func (s *TelemetryService) WebSocketHandler(w http.ResponseWriter, r *http.Request) {
	// TODO: Implement WebSocket for real-time telemetry streaming
	// This would allow real-time HR display on web dashboard
	http.Error(w, "WebSocket not implemented", http.StatusNotImplemented)
}

func getDBConnString() string {
	return "postgres://user:password@localhost:5432/titan_telemetry?sslmode=disable"
}