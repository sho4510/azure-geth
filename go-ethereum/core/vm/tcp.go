package vm

import (
    "net"
    "net/http"
    "bufio"
    "io"
    "fmt"
	"io/ioutil"

    "strings"
)

func sendCommandHttp(url string, command string) string {
    requestBody := strings.NewReader(command)

	resp, err := http.Post(url, "text/plain", requestBody)
	if err != nil {
		return fmt.Sprintf("Error making HTTP request: %v", err)
	}

	body, err := ioutil.ReadAll(resp.Body)
	if err != nil {
		return fmt.Sprintf("Error reading response body: %v", err)
	}
	resp.Body.Close()

	return string(body)
}

func sendCommandTcp(url string, command string) string {
        // サーバーに接続
        conn, err := net.Dial("tcp", url)
        if err != nil {
            return err.Error()
        }
    
        // サーバーにコマンドを送信
        _, err = io.WriteString(conn, command+"\n");
        if err != nil {
            return err.Error()
        }
    
        // サーバーからの応答を受け取り表示
        response, err := bufio.NewReader(conn).ReadString('\n')
        if err != nil {
            return err.Error()
        }

        conn.Close()

        response = strings.ReplaceAll(response, "\n", "")
    
        return response
}
