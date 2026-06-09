# skills

`/iterate` - communicate with ai agent via file.

For a new discussion

1. create a text file with the initial prompt
2. run `/iterate <filename>` in the ai agent of your choice (claude, opencode etc.)
3. ai agent would run as usual, but answer would get appended to the file
4. leave inline comments in the file inside last answer,
   prefixed with `i!`, e.g. `i! elaborate this paragraph`
5. run `/iterate`
6. goto #3

If continuing already started discussion - begin from #2.

## why?

1. transparently saves all discussion, can be saved/resumed at any moment
2. allows for unlimited inline comments directly where you want them
2. cross-tool, easy to search and store, as simple format as possible

## installation

To install use one of:

- `make install-copy`
- `make install-symplink`

To remove:

- `make remove`

## usage

From your ai agent:

`/iterate <filename>` - begin or continue a discussion via file.
`/iterate` - add new iteration to already running discussion.
