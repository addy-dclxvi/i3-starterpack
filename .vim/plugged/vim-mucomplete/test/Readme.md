# MUcomplete test folder

This folder contains:

- a Vim script to test the behaviour of MUcomplete;
- a Vim script to profile MUcomplete's performance.

To run the test suite, execute:

```
vim -u ../troubleshooting_vimrc.vim ./test_mucomplete.vim
```

then source the script with `:source %`.

To measure MUcomplete's performance, source `profile_mucomplete.vim`. The
profile is written into a `*.profile` file inside the `test` folder.

