package main

import (
	_ "embed"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/exec"
	"runtime"
	"strings"
	"sync"
	"time"
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

//go:embed static/index.html
var indexHTML string

func envOrDefault(name, fallback string) string {
	value := os.Getenv(name)
	if value == "" {
		return fallback
	}
	return value
}

func openBrowserEnabled() bool {
	value := strings.ToLower(strings.TrimSpace(os.Getenv("ANCLICK_OPEN_BROWSER")))
	return value != "0" && value != "false" && value != "no"
}

func browserURL(host, port string) string {
	if host == "" || host == "0.0.0.0" || host == "::" {
		host = "127.0.0.1"
	}
	return fmt.Sprintf("http://%s:%s/", host, port)
}

func openBrowser(url string) error {
	var cmd *exec.Cmd
	switch runtime.GOOS {
	case "windows":
		cmd = exec.Command("rundll32", "url.dll,FileProtocolHandler", url)
	case "darwin":
		cmd = exec.Command("open", url)
	default:
		cmd = exec.Command("xdg-open", url)
	}
	return cmd.Start()
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

func indexPage(w http.ResponseWriter, r *http.Request) {
	if r.URL.Path != "/" {
		http.NotFound(w, r)
		return
	}
	w.Header().Set("Content-Type", "text/html;charset=utf-8")
	_, _ = w.Write([]byte(indexHTML))
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
	mux.HandleFunc("/", indexPage)
	mux.HandleFunc("/get_status_anclick", getStatus)
	mux.HandleFunc("/set_false_anclick", setStatus(false, "已将状态修改为false"))
	mux.HandleFunc("/set_true_anclick", setStatus(true, "已将状态修改为true"))

	log.Printf("安点击网络联动服务启动: http://%s:%s", publicHost, port)
	log.Printf("网页控制台: http://%s:%s/", publicHost, port)
	log.Printf("查询状态: http://%s:%s/get_status_anclick", publicHost, port)
	log.Printf("置为false: http://%s:%s/set_false_anclick", publicHost, port)
	log.Printf("置为true: http://%s:%s/set_true_anclick", publicHost, port)
	if openBrowserEnabled() {
		url := browserURL(host, port)
		go func() {
			time.Sleep(500 * time.Millisecond)
			if err := openBrowser(url); err != nil {
				log.Printf("自动打开浏览器失败，可手动访问 %s: %v", url, err)
			}
		}()
	}
	server := &http.Server{
		Addr:              addr,
		Handler:           mux,
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       10 * time.Second,
		WriteTimeout:      10 * time.Second,
		IdleTimeout:       60 * time.Second,
	}
	if err := server.ListenAndServe(); err != nil {
		log.Fatalf("服务启动失败: %v", err)
	}
}
