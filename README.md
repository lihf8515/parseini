# parseini
A high-performance ini parse library for nim.
the ``parseini`` module implements a high performance configuration file
parser, evolved from ``parsecfg``.
the configuration file's syntax is similar to the Windows ``.ini``
format, but much more powerful, as it is not a line based parser. string
literals, raw string literals and triple quoted string literals are 
supported as in the nim programming language.
the module supports annotation statements, does not delete comment
statements and redundant blank characters, leaving the original style
and you can specify comment symbol.


This is a simple example of a configuration file.
=================================================

    charset="utf-8"
    [Package]
    name="hello"
    --threads:"on"
    [Author]
    name="lihf8515"
    qq="10214028"
    email="lihaifeng@wxm.com"
    
Specifies the comment symbol, the default comment symbol is "#" and ";".
==============================================================================

    import parseini
    var cfg=loadConfig("config.ini", {'&'})
    
Creating a configuration file.
==============================

    import parseini
    var cfg=newConfig()
    cfg.setSectionKey("","charset","utf-8")
    cfg.setSectionKey("Package","name","hello")
    cfg.setSectionKey("Package","--threads","on")
    cfg.setSectionKey("Author","name","lihf8515")
    cfg.setSectionKey("Author","qq","10214028")
    cfg.setSectionKey("Author","email","lihaifeng@wxm.com")
    cfg.writeConfig("config.ini")
    echo cfg

Reading a configuration file.
returns the specified default value if the specified key does not exist.
========================================================================

    import parseini
    var cfg = loadConfig("config.ini")
    var charset = cfg.getSectionValue("","charset")
    var threads = cfg.getSectionValue("Package","--threads")
    var pname = cfg.getSectionValue("Package","name")
    var name = cfg.getSectionValue("Author","name")
    var qq = cfg.getSectionValue("Author","qq")
    var email = cfg.getSectionValue("Author","email","10214028@qq.com")
    echo pname & "\n" & name & "\n" & qq & "\n" & email

Modifying a configuration file.
=========================================================

    import parseini
    var cfg = loadConfig("config.ini")
    cfg.setSectionKey("Author","name","lhf")
    cfg.setSectionKey("Author","qq","10214028")
    cfg.writeConfig("config.ini")
    echo cfg

Deleting a section key in a configuration file.
===============================================

    import parseini
    var cfg = loadConfig("config.ini")
    cfg.delSectionKey("Author","email")
    cfg.writeConfig("config.ini")
    echo cfg
