package main

import (
	"errors"
	"fmt"
	"io/ioutil"
	"log"
	"os"
	"strings"
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

func (p *TestParser) startsWith(val string) bool {
	valueLen := uint(len(val))
	if p.pos+valueLen > p.length() {
		return false
	}
	return strings.HasSuffix(string(p.input[p.pos:p.pos+valueLen]), val)
}

func (p *TestParser) parseComment() *Comment {
	p.expect("///")
	// todo

	return &Comment{""}
}

func parseKrugProgram(input []rune) []*Comment {
	parser := &TestParser{
		input: input,
		pos:   0,
	}

	comments := []*Comment{}
	for parser.hasNext() {
		if parser.startsWith("///") {
			comments = append(comments, parser.parseComment())
		}
		parser.consume()
	}

	return comments
}

func testKrugProgram(filePath string) error {
	contents, err := ioutil.ReadFile(filePath)
	if err != nil {
		return errors.New("failed to load file '" + filePath + "'")
	}

	comments := parseKrugProgram([]rune(string(contents)))

	stdout := []string{}
	stderr := []string{}

	var target *[]string
	for _, c := range comments {
		if strings.Compare(c.contents, ".stdout") == 0 {
			target = &stdout
			continue
		} else if strings.Compare(c.contents, ".stderr") == 0 {
			target = &stderr
			continue
		}

		if target != nil {
			fmt.Println("yo go tii '"+c.contents, "'")
			*target = append(*target, c.contents)
		}
	}

	fmt.Println("STDOUT EXPECTING:")
	for _, o := range stdout {
		fmt.Println(o)
	}

	return nil
}

func main() {
	filesToTest := []string{}
	for _, arg := range os.Args {
		if strings.HasSuffix(arg, ".krug") {
			filesToTest = append(filesToTest, arg)
		}
	}

	for _, file := range filesToTest {
		log.Print("Testing '" + file + "' ")
		if err := testKrugProgram(file); err != nil {
			log.Print("[-] - ", err.Error())
		} else {
			log.Print("[x]")
		}
	}
}
