package main

import (
	"bytes"
	"errors"
	"fmt"
	"io"
	"io/ioutil"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"syscall"
	"time"
)

type Comment struct {
	contents string
}

func (c *Comment) String() string {
	return "# " + c.contents
}

type TestParser struct {
	input []rune
	pos   uint
}

func (p *TestParser) length() uint {
	count := len(p.input)
	if count <= 0 {
		return 0
	}
	return uint(len(p.input))
}

func (p *TestParser) hasNext() bool {
	return p.pos < p.length()
}

func (p *TestParser) consume() rune {
	r := p.input[p.pos]
	p.pos++
	return r
}

func (p *TestParser) expect(val string) bool {
	for _, r := range val {
		if p.consume() != r {
			log.Fatal("Unexpected!")
			return false
		}
	}
	return true
}

func (p *TestParser) peek() rune {
	return p.input[p.pos]
}

func (p *TestParser) consumeWhile(predicate func(r rune) bool) string {
	buffer := []rune{}
	for p.hasNext() && predicate(p.peek()) {
		buffer = append(buffer, p.consume())
	}
	return string(buffer)
}

func (p *TestParser) parseComment() *Comment {
	contents := []rune{}

	for p.hasNext() {
		if p.consume() >= ' ' {
			break
		}
	}

	for p.hasNext() {
		curr := p.consume()
		contents = append(contents, curr)
		if curr == '\n' || curr == '\r' {
			break
		}
	}

	result := strings.TrimSpace(string(contents))
	return &Comment{result}
}

type TestTask struct {
	name       string
	codeLength int
	passed     bool
	statusCode int
	testedAt   time.Time
	info       error
}

func parseKrugProgram(input []rune) []*Comment {
	p := &TestParser{
		input: input,
		pos:   0,
	}

	comments := []*Comment{}

	// file is empty.
	if p.length() == 0 {
		return comments
	}

	buffer := []rune{}
	for p.hasNext() {
		buffer = append(buffer, p.consume())

		if string(buffer) == "///" {
			comments = append(comments, p.parseComment())
			buffer = []rune{}
		}

		// reset buffer
		if len(buffer) > 3 {
			buffer = []rune{}
		}
	}

	return comments
}

func testKrugProgram(filePath string) *TestTask {
	contents, err := ioutil.ReadFile(filePath)
	if err != nil {
		return &TestTask{
			filePath,
			0,
			false,
			0,
			time.Now(),
			errors.New("failed to load file '" + filePath + "'"),
		}
	}

	if len(contents) == 0 {
		return &TestTask{
			filePath,
			0,
			false,
			0,
			time.Now(),
			errors.New("empty test file"),
		}
	}

	comments := parseKrugProgram([]rune(string(contents)))

	stdout, stderr := "", ""
	var target *string

	var expectedStatus int

	for i, c := range comments {
		if strings.Compare(c.contents, ".stdout") == 0 {
			target = &stdout
			continue
		} else if strings.Compare(c.contents, ".stderr") == 0 {
			target = &stderr
			continue
		} else if strings.Compare(c.contents, ".skip") == 0 {
			return &TestTask{
				filePath,
				len(contents),
				false,
				0,
				time.Now(),
				errors.New(".skip"),
			}
		} else if strings.Compare(c.contents, ".status") == 0 {
			stat, err := strconv.Atoi(comments[i+1].contents)
			if err != nil {
				log.Println(err.Error())
				continue
			}
			expectedStatus = stat
			i += 2
			continue
		}

		if target != nil {
			*target = *target + c.contents + "\n"
		}
	}

	// get the cwd
	exe, err := os.Executable()
	if err != nil {
		return &TestTask{
			filePath,
			len(contents),
			false,
			0,
			time.Now(),
			err,
		}
	}
	dir := filepath.Dir(exe)

	// look for the krug compiler
	// binary in the cwd
	binary, err := exec.LookPath(dir + "/krug")
	if err != nil {
		return &TestTask{
			filePath,
			len(contents),
			false,
			0,
			time.Now(),
			err,
		}
	}

	outputExecutable := strings.TrimSuffix(filePath, filepath.Ext(filePath)) + ".out"
	args := []string{"b", filePath, "--out", outputExecutable}

	compilerCommand := exec.Command(binary, args...)
	showTestRunnerOutput := false
	if showTestRunnerOutput {
		compilerCommand.Stdout = os.Stdout
		compilerCommand.Stderr = os.Stdout
	}

	if err := compilerCommand.Start(); err != nil {
		return &TestTask{
			filePath,
			len(contents),
			false,
			0,
			time.Now(),
			errors.New("compiler invoke error"),
		}
	}

	if err := compilerCommand.Wait(); err != nil {
		return &TestTask{
			filePath,
			len(contents),
			false,
			0,
			time.Now(),
			errors.New("compiler wait() error"),
		}
	}

	runProgramCommand := exec.Command(fmt.Sprintf("%s", filepath.Join(dir, outputExecutable)))
	defer os.Remove(outputExecutable)

	outBuff := new(bytes.Buffer)
	if showTestRunnerOutput {
		runProgramCommand.Stdout = io.MultiWriter(outBuff, os.Stdout)
		runProgramCommand.Stderr = io.MultiWriter(outBuff, os.Stdout)
	} else {
		runProgramCommand.Stderr = outBuff
		runProgramCommand.Stderr = outBuff
	}

	if err := runProgramCommand.Start(); err != nil {
		return &TestTask{
			filePath,
			len(contents),
			false,
			0,
			time.Now(),
			errors.New("runtime error"),
		}
	}

	var actualStatus int
	if err := runProgramCommand.Wait(); err != nil {
		if exiterr, ok := err.(*exec.ExitError); ok {
			if status, ok := exiterr.Sys().(syscall.WaitStatus); ok {
				actualStatus = status.ExitStatus()
				if actualStatus != expectedStatus {
					log.Println("Expected exit status ", expectedStatus, " got ", actualStatus)
				}
			}
		}
	}

	// dont check outputs
	if len(stdout) == 0 && len(stderr) == 0 {
		return &TestTask{
			filePath,
			len(contents),
			true,
			actualStatus,
			time.Now(),
			nil,
		}
	}

	out := outBuff.String()
	if strings.Compare(out, stdout) == 0 {
		return &TestTask{
			filePath,
			len(contents),
			true,
			actualStatus,
			time.Now(),
			nil,
		}
	}

	log.Println("'" + filePath + "' failed!")
	log.Print("Expected")
	for _, e := range strings.Split(stdout, "\n") {
		fmt.Println("-", e)
	}

	log.Println("Actual")
	for _, o := range strings.Split(out, "\n") {
		fmt.Println("-", o)
	}

	return &TestTask{
		filePath,
		len(contents),
		false,
		actualStatus,
		time.Now(),
		nil,
	}
}

func main() {
	filesToTest := []string{}
	for _, arg := range os.Args {
		if strings.HasSuffix(arg, ".krug") {
			filesToTest = append(filesToTest, arg)
		}
	}

	for _, file := range filesToTest {
		testKrugProgram(file)
	}
}
