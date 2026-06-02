package main

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"sync"
)

const (
	defaultHost       = "0.0.0.0"
	defaultPort       = "27890"
	defaultPublicHost = "49.235.153.44"
)

type stateStore struct {
	mu     sync.RWMutex
	status bool
}

type response struct {
	Code   int    `json:"code"`
	Status *bool  `json:"status,omitempty"`
	Msg    string `json:"msg"`
}

var state = stateStore{status: true}

func envOrDefault(name, fallback string) string {
	value := os.Getenv(name)
	if value == "" {
		return fallback
	}
	return value
}

func writeJSON(w http.ResponseWriter, httpStatus int, resp response) {
	w.Header().Set("Content-Type", "application/json;charset=utf-8")
	w.WriteHeader(httpStatus)
	if err := json.NewEncoder(w).Encode(resp); err != nil {
		log.Printf("write response failed: %v", err)
	}
}

func allowRequest(w http.ResponseWriter, r *http.Request) bool {
	w.Header().Set("Access-Control-Allow-Origin", "*")
	w.Header().Set("Access-Control-Allow-Methods", "GET, OPTIONS")
	w.Header().Set("Access-Control-Allow-Headers", "Content-Type")

	if r.Method == http.MethodOptions {
		w.WriteHeader(http.StatusNoContent)
		return false
	}
	if r.Method != http.MethodGet {
		writeJSON(w, http.StatusMethodNotAllowed, response{
			Code: http.StatusMethodNotAllowed,
			Msg:  "只支持GET请求",
		})
		return false
	}
	return true
}

func getStatus(w http.ResponseWriter, r *http.Request) {
	if !allowRequest(w, r) {
		return
	}

	state.mu.RLock()
	status := state.status
	state.mu.RUnlock()

	writeJSON(w, http.StatusOK, response{
		Code:   http.StatusOK,
		Status: &status,
		Msg:    "查询成功",
	})
}

func setStatus(value bool, msg string) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if !allowRequest(w, r) {
			return
		}

		state.mu.Lock()
		state.status = value
		state.mu.Unlock()

		writeJSON(w, http.StatusOK, response{
			Code: http.StatusOK,
			Msg:  msg,
		})
	}
}

func main() {
	host := envOrDefault("ANCLICK_HOST", defaultHost)
	port := envOrDefault("ANCLICK_PORT", defaultPort)
	publicHost := envOrDefault("ANCLICK_PUBLIC_HOST", defaultPublicHost)
	addr := fmt.Sprintf("%s:%s", host, port)

	mux := http.NewServeMux()
	mux.HandleFunc("/get_status_anclick", getStatus)
	mux.HandleFunc("/set_false_anclick", setStatus(false, "已将状态修改为false"))
	mux.HandleFunc("/set_true_anclick", setStatus(true, "已将状态修改为true"))

	log.Printf("安点击网络联动服务启动: http://%s:%s", publicHost, port)
	log.Printf("查询状态: http://%s:%s/get_status_anclick", publicHost, port)
	log.Printf("置为false: http://%s:%s/set_false_anclick", publicHost, port)
	log.Printf("置为true: http://%s:%s/set_true_anclick", publicHost, port)
	if err := http.ListenAndServe(addr, mux); err != nil {
		log.Fatalf("服务启动失败: %v", err)
	}
}
