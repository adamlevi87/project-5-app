#!/bin/bash

# Skaffold management script
FRONTEND_CONFIG="./skaffold/skaffold-frontend.yaml"
BACKEND_CONFIG="./skaffold/skaffold-backend.yaml"
FRONTEND_LOG="./skaffold/logs/frontend-skaffold.log"
BACKEND_LOG="./skaffold/logs/backend-skaffold.log"
PID_FILE="./skaffold/skaffold.pids"

start_skaffold() {
    echo "Starting Skaffold processes..."
    
    # Check if already running
    if [ -f "$PID_FILE" ]; then
        echo "Skaffold processes may already be running. Use 'stop' first or check with 'status'."
        return 1
    fi
    
    # Start frontend
    echo "Starting frontend skaffold..."
    nohup skaffold dev -f "$FRONTEND_CONFIG" > "$FRONTEND_LOG" 2>&1 &
    FRONTEND_PID=$!
    
    # Start backend
    echo "Starting backend skaffold..."
    nohup skaffold dev -f "$BACKEND_CONFIG" > "$BACKEND_LOG" 2>&1 &
    BACKEND_PID=$!
    
    # Save PIDs
    echo "$FRONTEND_PID" > "$PID_FILE"
    echo "$BACKEND_PID" >> "$PID_FILE"
    
    echo "✅ Skaffold processes started:"
    echo "   Frontend PID: $FRONTEND_PID"
    echo "   Backend PID: $BACKEND_PID"
    echo "   Logs: tail -f $FRONTEND_LOG or tail -f $BACKEND_LOG"
}

stop_skaffold() {
    echo "Stopping Skaffold processes..."
    
    if [ ! -f "$PID_FILE" ]; then
        echo "No PID file found. Processes may not be running."
        return 1
    fi
    
    # Read PIDs
    FRONTEND_PID=$(sed -n '1p' "$PID_FILE")
    BACKEND_PID=$(sed -n '2p' "$PID_FILE")
    
    # Stop processes
    if [ ! -z "$FRONTEND_PID" ]; then
        echo "Stopping frontend (PID: $FRONTEND_PID)..."
        kill "$FRONTEND_PID" 2>/dev/null || echo "Frontend process not found"
    fi
    
    if [ ! -z "$BACKEND_PID" ]; then
        echo "Stopping backend (PID: $BACKEND_PID)..."
        kill "$BACKEND_PID" 2>/dev/null || echo "Backend process not found"
    fi
    
    # Clean up PID file
    rm -f "$PID_FILE"
    
    echo "✅ Skaffold processes stopped"
}

status_skaffold() {
    echo "Checking Skaffold process status..."
    
    if [ ! -f "$PID_FILE" ]; then
        echo "❌ No PID file found. Processes are not running."
        return 1
    fi
    
    # Read PIDs
    FRONTEND_PID=$(sed -n '1p' "$PID_FILE")
    BACKEND_PID=$(sed -n '2p' "$PID_FILE")
    
    # Check if processes are running
    if kill -0 "$FRONTEND_PID" 2>/dev/null; then
        echo "✅ Frontend skaffold is running (PID: $FRONTEND_PID)"
    else
        echo "❌ Frontend skaffold is not running"
    fi
    
    if kill -0 "$BACKEND_PID" 2>/dev/null; then
        echo "✅ Backend skaffold is running (PID: $BACKEND_PID)"
    else
        echo "❌ Backend skaffold is not running"
    fi
}

logs_skaffold() {
    case "$2" in
        "frontend")
            echo "Following frontend logs..."
            tail -f "$FRONTEND_LOG"
            ;;
        "backend")
            echo "Following backend logs..."
            tail -f "$BACKEND_LOG"
            ;;
        *)
            echo "Usage: $0 logs [frontend|backend]"
            echo "Available log files:"
            echo "  Frontend: $FRONTEND_LOG"
            echo "  Backend: $BACKEND_LOG"
            ;;
    esac
}

show_help() {
    echo "Skaffold Management Script"
    echo ""
    echo "Usage: $0 [start|stop|status|logs|help]"
    echo ""
    echo "Commands:"
    echo "  start   - Start both frontend and backend skaffold processes"
    echo "  stop    - Stop both skaffold processes"
    echo "  status  - Check if processes are running"
    echo "  logs    - Show logs (use 'logs frontend' or 'logs backend')"
    echo "  help    - Show this help message"
    echo ""
    echo "Files:"
    echo "  Frontend config: $FRONTEND_CONFIG"
    echo "  Backend config: $BACKEND_CONFIG"
    echo "  Frontend logs: $FRONTEND_LOG"
    echo "  Backend logs: $BACKEND_LOG"
}

# Main script logic
case "$1" in
    "start")
        start_skaffold
        ;;
    "stop")
        stop_skaffold
        ;;
    "status")
        status_skaffold
        ;;
    "logs")
        logs_skaffold "$@"
        ;;
    "help"|"--help"|"-h")
        show_help
        ;;
    *)
        echo "Usage: $0 [start|stop|status|logs|help]"
        echo "Run '$0 help' for more information"
        exit 1
        ;;
esac