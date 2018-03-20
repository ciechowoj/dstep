/**
 * Copyright: Copyright (c) 2018 Wojciech Szęszoł. All rights reserved.
 * Authors: Wojciech Szęszoł
 * Version: Initial created: Mar 21, 2018
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */
module dstep.translator.GlobalContext;

import std.parallelism;

import clang.c.Index;
import clang.Cursor;
import clang.Index;
import clang.SourceRange;
import clang.TranslationUnit;

import dstep.translator.CommentIndex;
import dstep.translator.IncludeHandler;
import dstep.translator.MacroDefinition;
import dstep.translator.MacroIndex;
import dstep.translator.Options;
import dstep.translator.Output;
import dstep.translator.Translator;
import dstep.translator.TypedefIndex;
import dstep.translator.HeaderIndex;
import dstep.translator.TypeInference;
import dstep.translator.Context;

class GlobalContext
{
    public Options options;
    public Context[] contexts;
    public TypedMacroDefinition[string] macroDefinitions;
    public TaskPool taskPool;

    public this(Context[] contexts, Options options, TaskPool taskPool)
    {
        this.options = options;
        this.contexts = contexts;

        foreach(context; this.contexts)
        {
            context.global = this;
        }

        // this.macroDefinitions = inferMacroSignatures(context);
    }


}
