# parseini
A high-performance ini parse library for nim.
The ``parseini`` module implements a high performance configuration file
parser, evolved from ``parsecfg``.
The configuration file's syntax is similar to the Windows ``.ini``
format, but much more powerful, as it is not a line based parser. String
literals, raw string literals and triple quoted string literals are 
supported as in the Nim programming language.
The module supports annotation statements, does not delete comment
statements and redundant blank characters, leaving the original style
and you can specify annotation delimiters.

Here is an example of how to use the configuration file parser:
=============================================================
    import
      os, parseini, strutils, streams

    var f = newFileStream(paramStr(1), fmRead)
    if f != nil:
      var p: CfgParser
      open(p, f, paramStr(1))
      while true:
        var e = next(p)
        case e.kind
        of cfgEof: break
        of cfgSectionStart:   ## a ``[section]`` has been parsed
          echo("new section: " & e.section)
        of cfgKeyValuePair:
          echo("key-value-pair: " & e.key & ": " & e.keyVal.value)
        of cfgOption:
          echo("command: " & e.key & ": " & e.keyVal.value)
        of cfgError:
          echo(e.msg)
      close(p)
    else:
      echo("cannot open: " & paramStr(1))

This is a simple example of a configuration file.
===============================================

    charset="utf-8"
    [Package]
    name="hello"
    --threads:"on"
    [Author]
    name="lihf8515"
    qq="10214028"
    email="lihaifeng@wxm.com"

Support for reading multivalued KEY
===================================
    import parseini
    var cfg=newConfig()
    cfg.gets("Author","name")
    
Creating a configuration file.
============================

    import parseini
    var cfg=newConfig()
    cfg.set("","charset","utf-8")
    cfg.set("Package","name","hello")
    cfg.set("Package","--threads","on")
    cfg.set("Author","name","lihf8515")
    cfg.set("Author","qq","10214028")
    cfg.set("Author","email","lihaifeng@wxm.com")
    cfg.write("config.ini")
    echo cfg

Reading a configuration file.
===========================

    import parseini
    var cfg = loadConfig("config.ini")
    var charset = cfg.get("","charset")
    var threads = cfg.get("Package","--threads")
    var pname = cfg.get("Package","name")
    var name = cfg.get("Author","name")
    var qq = cfg.get("Author","qq")
    var email = cfg.get("Author","email")
    echo pname & "\n" & name & "\n" & qq & "\n" & email

Modifying a configuration file.
=============================

    import parseini
    var cfg = loadConfig("config.ini")
    cfg.set("Author","name","lhf")
    cfg.write("config.ini")
    echo cfg

Deleting a section key in a configuration file.
=============================================

    import parseini
    var cfg = loadConfig("config.ini")
    cfg.del("Author","email")
    cfg.write("config.ini")
    echo cfg
