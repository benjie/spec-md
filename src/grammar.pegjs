{
  var indentStack = [];
  var indent = 0;

  function orderify(list) {
    list.ordered = true;
    list.items.forEach(function (item) {
      if (item.contents[item.contents.length - 1].type === 'List') {
        orderify(item.contents[item.contents.length - 1]);
      }
    });
    return list;
  }
}

// Lines and Indentation

INDENT = &( lineStart depth:indentDepth &{ return depth >= indent + 2; } {
  indentStack.push(indent);
  indent = depth;
})

DEEP_INDENT = &( lineStart depth:indentDepth &{ return depth >= indent + 4; } {
  indentStack.push(indent);
  indent = depth;
})

BLOCK = blockStart depth:indentDepth &{ return depth === indent || depth === indent + 1; } {
  return depth;
}

LINE = lineStart depth:indentDepth &{ return depth >= indent; } {
  return depth;
}

DEDENT = &lineStart !{ indentStack.length === 0 } {
  indent = indentStack.pop();
}

NL = "\n" / "\r" / "\r\n"
NOT_NL = [^\n\r]
_ = ' '*
EOF = NL* !.

lineStart = NL+ / & { return offset() === 0 }

blockStart = (NL NL+) / & { return offset() === 0 }

indentDepth = sp:$' '* { return sp.length; }


// Document

document = title:title? contents:documentContent* EOF {
  return {
    type: 'Document',
    title: title,
    contents: contents
  };
}

title = BLOCK !'#' value:$NOT_NL+ NL ('---' '-'* / '===' '='*) &NL {
  return {
    type: 'DocumentTitle',
    value: value
  };
}

SEC_CLOSE = _ '#'* &NL

sectionTitle = $titleChar+
titleChar = [^\n\r# ] / [# ] titleChar

sectionNum = (sectionNumPart '.')* sectionNumPart
sectionNumPart = [0-9]+ / '*'

section1 = BLOCK '#' !'#' _ secnum:$sectionNum? _ title:sectionTitle SEC_CLOSE contents:section1Content* {
  return {
    type: 'Section',
    secnum: secnum,
    title: title,
    contents: contents
  };
}

section2 = BLOCK '##' !'#' _ secnum:$sectionNum? _ title:sectionTitle SEC_CLOSE contents:section2Content* {
  return {
    type: 'Section',
    secnum: secnum,
    title: title,
    contents: contents
  };
}

section3 = BLOCK '###' !'#' _ secnum:$sectionNum? _ title:sectionTitle SEC_CLOSE contents:section3Content* {
  return {
    type: 'Section',
    secnum: secnum,
    title: title,
    contents: contents
  };
}

section4 = BLOCK '####' !'#' _ secnum:$sectionNum? _ title:sectionTitle SEC_CLOSE contents:section4Content* {
  return {
    type: 'Section',
    secnum: secnum,
    title: title,
    contents: contents
  };
}

section5 = BLOCK '#####' !'#' _ secnum:$sectionNum? _ title:sectionTitle SEC_CLOSE contents:section5Content* {
  return {
    type: 'Section',
    secnum: secnum,
    title: title,
    contents: contents
  };
}

documentContent = import1 / section1 / sectionContent
section1Content = import2 / section2 / sectionContent
section2Content = import3 / section3 / sectionContent
section3Content = import4 / section4 / sectionContent
section4Content = import5 / section5 / sectionContent
section5Content = sectionContent

sectionContent = importRel
               / note
               / todo
               / indentCode
               / blockCode
               / algorithm
               / production
               / table
               / list
               / blockEdit
               / paragraph


// Import

importLink = link:link &( BLOCK / EOF ) &{
  return link.url.slice(-3) === '.md' && !/^\/([a-z]*:\/\/)/.test(link.url);
} {
  return {
    type: 'Import',
    path: link.url
  };
}

importRel = BLOCK importLink:importLink &NL { return importLink; }
import1 = BLOCK '#' _ importLink:importLink SEC_CLOSE { return importLink; }
import2 = BLOCK '##' _ importLink:importLink SEC_CLOSE { return importLink; }
import3 = BLOCK '###' _ importLink:importLink SEC_CLOSE { return importLink; }
import4 = BLOCK '####' _ importLink:importLink SEC_CLOSE { return importLink; }
import5 = BLOCK '#####' _ importLink:importLink SEC_CLOSE { return importLink; }


// Block Edit

blockEdit = blockIns / blockDel

blockIns = BLOCK '{++' &BLOCK contents:sectionContent* BLOCK '++}' &(BLOCK / EOF) {
  return {
    type: 'BlockIns',
    contents: contents
  };
}

blockDel = BLOCK '{--' &BLOCK contents:sectionContent* BLOCK '--}' &(BLOCK / EOF) {
  return {
    type: 'BlockDel',
    contents: contents
  };
}


// Paragraph

paragraph = BLOCK !"#" contents:content+ {
  return {
    type: 'Paragraph',
    contents: contents
  };
}

content = inlineEdit / inlineCode / reference / bold / italic / link / image / htmlTag / text

textChar = '\\' [\\`*_{}[\]()<>#+\-!|]
         / [^\n\r+\-{`|*[!<]
         / '{' !('++' / '--')
         / '++' !'}'
         / '+' !'+}'
         / '--' !'}'
         / '-' !'-}'
         / !image '!'
         / !htmlTag '<'
         / NL !(NL / ' '* listBullet)

text = value:$textChar+ {
  return {
    type: 'Text',
    value: value
  };
}

note = BLOCK 'NOTE'i (':' / ' ') _ contents:content* {
  return {
    type: 'Note',
    contents: contents
  };
}

todo = BLOCK ('TODO'i / 'TK'i) (':' / ' ') _ contents:content* {
  return {
    type: 'Todo',
    contents: contents
  };
}

bold = '**' contents:(inlineCode / link / italic / text)+ '**' {
  return {
    type: 'Bold',
    contents: contents
  };
}

italic = '*' contents:(inlineCode / link / text)+ '*' {
  return {
    type: 'Italic',
    contents: contents
  };
}

inlineEdit = ins / del

ins = '{++' contents:content* '++}' {
  return {
    type: 'Ins',
    contents: contents
  };
}

del = '{--' contents:content* '--}' {
  return {
    type: 'Del',
    contents: contents
  };
}

htmlTag = tag:$("<" "/"? [a-z]+ [^>]* ">") {
  return {
    type: 'HTMLTag',
    tag: tag
  };
}

reference = '|' ref:(call / value / token) '|' {
  return ref;
}

inlineCode = '`' code:$[^`\n\r]+ '`' {
  return {
    type: 'InlineCode',
    code: code
  };
}

blockCode = BLOCK '```' counter:'!'? lang:($NOT_NL+)? NL code:$([^`] / '`' [^`] / '``' [^`])+ '```' {
  // dedent codeblock by current indent level?
  return {
    type: 'Code',
    counter: counter !== null,
    lang: lang,
    code: code
  };
}

indentCode = DEEP_INDENT code:(indentCodeLine+)? DEDENT &{ return code !== null } {
  return {
    type: 'Code',
    code: code.join('\n')
  };
}

indentCodeLine = depth:LINE code:$NOT_NL+ {
  return Array(depth - indent + 1).join(' ') + code;
}


// Link & Image

link = '[' contents:linkContent* '](' _ url:$[^)\n\r]+ _ ')' {
  return {
    type: 'Link',
    contents: contents,
    url: url
  };
}

linkContent = inlineEdit / inlineCode / bold / italic / image / htmlTag / linkText

linkTextChar = '\\' [\\`*_{}[\]()#+\-!]
             / [^\]\n\r+\-{`*!<]
             / '{' !('++' / '--')
             / '++' !'}'
             / '+' !'+}'
             / '--' !'}'
             / '-' !'-}'
             / !image '!'
             / !htmlTag '<'

linkText = value:$linkTextChar+ {
  return {
    type: 'Text',
    value: value
  };
}

image = '![' alt:$[^\]\n\r]+ '](' _ url:$[^)\n\r]+ _ ')' {
  return {
    type: 'Image',
    alt: alt,
    url: url
  };
}


// List

list = indentedList / unorderedList / orderedList

indentedList = INDENT list:(unorderedList / orderedList) DEDENT {
  return list;
}

unorderedList = &(LINE unorderedBullet) items:listItem+ {
  return {
    type: 'List',
    ordered: false,
    items: items
  };
}

orderedList = &(LINE orderedBullet) items:listItem+ {
  return {
    type: 'List',
    ordered: true,
    items: items
  };
}

listItem = LINE bullet:listBullet _ contents:content* sublist:indentedList? {
  return {
    type: 'ListItem',
    contents: sublist ? contents.concat([sublist]) : contents
  };
}

listBullet = unorderedBullet / orderedBullet
unorderedBullet = $(('-' / '+' / '*') ' ')
orderedBullet = $(([1-9]+ '.') ' ')


// Table

table = BLOCK !'#' ('|' _)? headers:tableCells _ '|'? LINE [ -|]+ rows:tableRow+ {
  return {
    type: 'Table',
    headers: headers,
    rows: rows
  };
}

tableRow = LINE !'#' ('|' _)? cells:tableCells _ '|'? {
  return cells;
}

tableCells = first:tableCell rest:(_ '|' _ tableCell)+ {
  return [first].concat(rest.map(function (nodes) {
    return nodes[3];
  }));
}

tableCell = contents:tableCellContent+ {
  return contents;
}

tableCellContent = inlineEdit / inlineCode / reference / bold / italic / link / image / htmlTag / tableCellText

tableCellTextChar = '\\' [\\`*_{}[\]()#+\-!]
                  / [^\n\r+\-{`|*[!<]
                  / '{' !('++' / '--')
                  / '++' !'}'
                  / '+' !'+}'
                  / '--' !'}'
                  / '-' !'-}'
                  / !image '!'
                  / !htmlTag '<'

tableCellText = value:$tableCellTextChar+ {
  return {
    type: 'Text',
    value: value
  };
}


// Names

localName = $([_a-z][_a-zA-Z0-9]*)
globalName = $([A-Z][_a-zA-Z]*)
paramName = $([_a-zA-Z][_a-zA-Z0-9]*)


// Algorithm

algorithm = BLOCK name:call _ '::' steps:list {
  return {
    type: 'Algorithm',
    name: name,
    steps: orderify(steps)
  };
}

call = name:(globalName / localName) '(' _ args:callArg* _ ')' {
  return {
    type: 'Call',
    name: name,
    args: args
  };
}

callArg = value:value [, ]* {
  return value;
}

value = stringLiteral / keyword / variable

stringLiteral = value:$('"' [^\"]* '"') {
  return {
    type: 'StringLiteral',
    value: value
  };
}

keyword = value:$('null' / 'true' / 'false' / 'undefined') {
  return {
    type: 'Keyword',
    value: value
  };
}

variable = name:localName {
  return {
    type: 'Variable',
    name: name
  };
}


// Grammar productions

production = oneOfProduction / simpleProduction / multiProduction

simpleProduction = BLOCK name:nonTerminal _ '::' _ tokens:token+ {
  return {
    type: 'Production',
    name: name,
    defs: [{
      type: 'RHS',
      tokens: tokens
    }]
  };
}

oneOfProduction = BLOCK name:nonTerminal _ '::' _ 'one of' tokenRows:oneOfRow+ {
  return {
    type: 'OneOfProduction',
    name: name,
    defs: tokenRows
  };
}

oneOfRow = _ NL? _ tokens:oneOfToken+ {
  return tokens;
}

oneOfToken = _ token:(prose / nonTerminal / regexp / quotedTerminal / terminal) {
  return token;
}

multiProduction = BLOCK name:nonTerminal _ '::' defs:productionDefs {
  return {
    type: 'Production',
    name: name,
    defs: defs
  };
}

productionDefs = indentedDefs / grammarDef+

indentedDefs = INDENT defs:grammarDef+ DEDENT {
  return defs;
}

grammarDef = LINE listBullet _ condition:condition? _ tokens:token+ {
  return {
    type: 'RHS',
    condition: condition,
    tokens: tokens
  };
}

condition = '[' condition:('+' / '~') param:paramName ']' {
  return {
    type: 'Condition',
    param: param,
    not: condition === '~'
  };
}

token = token:(prose / emptyToken / lookahead / nonTerminal / regexp / quotedTerminal / terminal) _ constraint:constraint? _ {
  return !constraint ? token : {
    type: 'Constrained',
    token: token,
    constraint: constraint
  };
}

prose = '"' text:$[^\"]+ '"' {
  return {
    type: 'Prose',
    text: text
  };
}

emptyToken = '[' _ 'empty' _ ']' {
  return {
    type: 'Empty'
  };
}

lookahead = '[' _ 'lookahead' _ not:'!'? _ set:(lookaheadSet/lookaheadItem)? _ closer:']'? {
  if (set === null) {
    error('Malformed lookahead. Did you forget tokens?');
  }
  if (closer === null) {
    error('Malformed lookahead. Did you forget a space after the token?');
  }
  return {
    type: 'Lookahead',
    not: not !== null,
    set: set
  };
}

lookaheadSet = '{' set:(_ !'}' token _ ','?)+ _ '}' {
  return set.map(function (nodes) { return nodes[2]; });
}

lookaheadItem = !']' token:token {
  return [token];
}

nonTerminal = name:globalName params:nonTerminalParams? list:'+'? opt:'?'? {
  return {
    type: 'NonTerminal',
    name: name,
    params: params,
    isList: list !== null,
    isOptional: opt !== null
  };
}

nonTerminalParams = '[' _ params:nonTerminalParam+ _ ']' {
  return params;
}

nonTerminalParam = conditional:'?'? name:paramName $[, ]* {
  return {
    type: 'NonTerminalParam',
    conditional: conditional === '?',
    name: name
  };
}

constraint = butNot

butNot = 'but not ' _ 'one of '? _ first:token rest:(_ ('or '/',') _ token)* {
  return {
    type: 'ButNot',
    tokens: [first].concat(rest.map(function (nodes) {
      return nodes[3];
    }))
  };
}

regexp = value:$('/' ([^/\n] / '\\/')+ '/') {
  return {
    type: 'RegExp',
    value: value
  };
}

quotedTerminal = '`' value:$([^`\n] / ('\\`'))+ '`' {
  return {
    type: 'Terminal',
    value: value
  };
}

terminal = value:$([^ \n"/`] [^ \n"\`,]*) {
  return {
    type: 'Terminal',
    value: value
  };
}
