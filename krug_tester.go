package main

import (
	"bytes"
	"errors"
	"fmt"
	"io/ioutil"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"syscall"

	"github.com/sergi/go-diff/diffmatchpatch"
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
	return p.pos < p.length()-1
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
		if curr == '\n' || curr == '\r' {
			break
		}
		contents = append(contents, curr)
	}

	result := strings.TrimSpace(string(contents))
	return &Comment{result}
}

func parseKrugProgram(input []rune) []*Comment {
	p := &TestParser{
		input: input,
		pos:   0,
	}

	comments := []*Comment{}

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

func testKrugProgram(filePath string) (bool, error) {
	contents, err := ioutil.ReadFile(filePath)
	if err != nil {
		return true, errors.New("failed to load file '" + filePath + "'")
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

			// remove me this doesnt really work that well
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
			*target = *target + c.contents + string('\n')
		}
	}

	exe, err := os.Executable()
	if err != nil {
		return true, err
	}

	dir := filepath.Dir(exe)

	binary, err := exec.LookPath(dir + "/krug")
	if err != nil {
		return true, err
	}
	args := []string{binary, "build", filePath}
	exec.Command(binary, args...)

	cmd := exec.Command(dir + "/a.out")

	var stdoutBuff, stderrBuff bytes.Buffer
	cmd.Stdout = &stdoutBuff
	cmd.Stderr = &stderrBuff

	if err := cmd.Wait(); err != nil {
		if exiterr, ok := err.(*exec.ExitError); ok {
			// The program has exited with an exit code != 0
			// This works on both Unix and Windows. Although package
			// syscall is generally platform dependent, WaitStatus is
			// defined for both Unix and Windows and in both cases has
			// an ExitStatus() method with the same signature.
			if status, ok := exiterr.Sys().(syscall.WaitStatus); ok {
				actualStatus := status.ExitStatus()
				if actualStatus != expectedStatus {
					log.Println("Expected exit status ", expectedStatus, " got ", actualStatus)
				}
			}
		}
	}

	out := string(stdoutBuff.Bytes())

	dmp := diffmatchpatch.New()
	diffs := dmp.DiffMain(out, stdout, true)

	if len(diffs) == 0 {
		return false, nil
	}

	log.Println("'" + filePath + "' failed!")
	log.Print("Expected")
	for _, e := range strings.Split(stdout, "\n") {
		fmt.Println("-", e)
	}

	log.Println("Actual")
	for _, o := range out {
		fmt.Println("-", o)
	}

	log.Println("Diff")
	fmt.Println(dmp.DiffPrettyText(diffs))

	return true, nil
}

func main() {
	filesToTest := []string{}
	for _, arg := range os.Args {
		if strings.HasSuffix(arg, ".krug") {
			filesToTest = append(filesToTest, arg)
		}
	}

	for _, file := range filesToTest {
		failed, err := testKrugProgram(file)
		if err != nil {
			log.Println("Tester failed!")
		}

		glyph := "x"
		if failed {
			glyph = "-"
		}
		log.Println("Tested '" + file + "' [" + glyph + "]")
	}
}
