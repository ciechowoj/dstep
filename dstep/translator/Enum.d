/**
 * Copyright: Copyright (c) 2012 Jacob Carlborg. All rights reserved.
 * Authors: Jacob Carlborg
 * Version: Initial created: May 10, 2012
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */
module dstep.translator.Enum;

import clang.c.Index;
import clang.Cursor;
import clang.Visitor;
import clang.Util;

import dstep.translator.Context;
import dstep.translator.Declaration;
import dstep.translator.Output;
import dstep.translator.Translator;
import dstep.translator.Type;

void translateEnumConstantDecl(
    Output output,
    Context context,
    Cursor cursor,
    string spelling,
    bool last)
{
    import std.format : format;

    output.singleLine(
        cursor.extent,
        "%s = %s%s",
        spelling,
        cursor.enum_.value,
        last ? "" : ",");
}

void generateEnumAliases(Output output, Context context, Cursor cursor, string spelling)
{
    string subscope = cursorScopeString(context, cursor) ~ ".";

    version (D1)
        enum fmt = "alias %2$s %1$s;";
    else
        enum fmt = "alias %1$s = %2$s;";

    foreach (item; cursor.all)
    {
        switch (item.kind)
        {
            case CXCursorKind.enumConstantDecl:
                output.singleLine(
                    fmt,
                    item.spelling,
                    subscope ~ item.spelling);
                break;

            default:
                break;
        }
    }
}

auto splitSpelling(string spelling)
{
    import std.algorithm;
    import std.ascii;
    import std.range;

    struct Range
    {
        private string spelling;
        private string next;
        private bool capitals;

        this(string spelling)
        {
            this.spelling = spelling.stripLeft('_');
            capitals = !spelling.canFind!isLower;
            popFront();
        }

        bool empty() const
        {
            return next.empty;
        }

        string front() const
        {
            return next;
        }

        void popFront()
        {
            if (spelling.empty)
            {
                next = spelling;
            }
            else
            {
                size_t end = capitals
                    ? spelling[1 .. $].countUntil!(a => a == '_')
                    : spelling[1 .. $].countUntil!(a => !a.isLower);

                end = end == -1 ? spelling.length : end + 1;
                next = spelling[0 .. end];
                spelling = spelling[end .. $].stripLeft('_');
            }
        }
    }

    return Range(spelling);
}

unittest
{
    import std.array;

    assert(splitSpelling("").array == []);
    assert(splitSpelling("__").array == []);
    assert(splitSpelling("x").array == ["x"]);
    assert(splitSpelling("X").array == ["X"]);
    assert(splitSpelling("xxx").array == ["xxx"]);
    assert(splitSpelling("xxxXxx").array == ["xxx", "Xxx"]);
    assert(splitSpelling("xxxXxxYyy").array == ["xxx", "Xxx", "Yyy"]);
    assert(splitSpelling("xxxXxxYYY").array == ["xxx", "Xxx", "Y", "Y", "Y"]);
    assert(splitSpelling("xxx_Xxx__YYY").array == ["xxx", "Xxx", "Y", "Y", "Y"]);
    assert(splitSpelling("__xxx_Xxx__YYY__").array == ["xxx", "Xxx", "Y", "Y", "Y"]);
    assert(splitSpelling("YYY").array == ["YYY"]);
    assert(splitSpelling("Y_Y__XXY").array == ["Y", "Y", "XXY"]);
    assert(splitSpelling("__Y_Y__XXY__").array == ["Y", "Y", "XXY"]);
}

string toCamelCase(string spelling)
{
    import std.algorithm;
    import std.array;
    import std.ascii;
    import std.math;

    auto split = spelling.splitSpelling();

    if (split.empty)
    {
        return string.init;
    }
    else
    {
        char[] camelCase(string x)
        {
            return (cast(char) x[0].toUpper) ~
                x[1 .. $].map!(x => cast(char) x.toLower).array;
        }

        char[] front;

        while (split.front.length == 1)
        {
            front ~= cast(char) split.front.front.toLower;
            split.popFront();
        }

        if (front.empty)
        {
            front = split.front.map!(x => cast(char) x.toLower).array;
            split.popFront();
        }

        return (front ~ split.map!camelCase.join).idup;
    }
}

unittest
{
    import std.array;

    assert("".toCamelCase() == "");
    assert("x".toCamelCase() == "x");
    assert("X".toCamelCase() == "x");
    assert("xy".toCamelCase() == "xy");
    assert("xy_zw".toCamelCase() == "xyZw");
    assert("xy_zw".toCamelCase() == "xyZw");
    assert("xyZw".toCamelCase() == "xyZw");
    assert("XY_ZW".toCamelCase() == "xyZw");
    assert("XXXy_ZW".toCamelCase() == "xxXyZW");
    assert("XXy_ZW".toCamelCase() == "xXyZW");
}

auto renameEnumMembers(MemberRange)(string enumSpelling, MemberRange memberSpellings)
{
    import std.array;
    import std.algorithm;
    import std.ascii;
    import std.range;

    struct Component
    {
        string spelling;
        size_t offset;
    }

    Component[] separateWords(string spelling)
    {
        Component[] result;

        size_t begin = 0;

        if (spelling.canFind!(a => a.isLower))
        {
            for (size_t i = 1; i < spelling.length; ++i)
            {
                if (spelling[i].isUpper ||
                    (spelling[i - 1] == '_' && spelling[i].isLower))
                {
                    if (!result.empty)
                        result.back.offset = begin;

                    result ~= Component(spelling[begin..i].stripRight('_'), i);
                    begin = i;
                }
            }
        }
        else
        {
            for (size_t i = 1; i < spelling.length; ++i)
            {
                if (spelling[i - 1] == '_')
                {
                    if (!result.empty)
                        result.back.offset = begin;

                    result ~= Component(spelling[begin .. i].stripRight('_'), i);
                    begin = i;
                }
            }
        }

        if (begin != spelling.length)
        {
            result ~= Component(
                spelling[begin .. $].stripRight('_'),
                spelling.length);
        }

        return result;
    }

    size_t trimWhenEnumIsCamelAndMemberIsCapitals(
        string enumSpelling,
        string memberSpelling,
        Component[] enumSeparated)
    {
        size_t numWords = 0;
        size_t offset = 0;
        string uppercasePrefix;

        while (offset < memberSpelling.length && numWords < enumSeparated.length)
        {
            if (!enumSeparated[numWords].spelling.canFind!isLower &&
                memberSpelling[offset .. $]
                    .startsWith(enumSeparated[numWords].spelling))
            {
                uppercasePrefix ~= enumSeparated[numWords].spelling;
                offset += enumSeparated[numWords].spelling.length;
                ++numWords;
            }
            else
            {
                break;
            }
        }

        return commonPrefix(uppercasePrefix, enumSpelling).length;
    }

    size_t refactorSingleton(string enumSpelling, string memberSpelling)
    {
        auto enumSeparated = separateWords(enumSpelling);
        auto memberSeparated = separateWords(memberSpelling);

        alias predicate = (a, b) =>
            a.spelling.startsWith!((a, b) => a.toLower == b.toLower)(b.spelling);

        auto prefix = commonPrefix!(predicate)(enumSeparated, memberSeparated);

        auto tentative = !prefix.empty
            ? memberSeparated[prefix.length - 1].offset
            : 0;

        if (!memberSeparated.canFind!((Component a) => a.spelling.canFind!isLower))
        {
            auto special = trimWhenEnumIsCamelAndMemberIsCapitals(
                enumSpelling,
                memberSpelling,
                enumSeparated);

            return max(tentative, special);
        }
        else
        {
            auto candidate = findSplitBefore(memberSpelling.retro, "_");
            return !candidate[1].empty
                ? max(candidate[1].walkLength, tentative)
                : tentative;
        }
    }

    struct Range
    {
        private MemberRange memberSpellings;
        private size_t prefixSize;

        this(string enumSpelling, MemberRange memberSpellings)
        {
            this.memberSpellings = memberSpellings;

            auto candidate = findSplitAfter(enumSpelling, "_");
            auto minorPrefix = fold!commonPrefix(memberSpellings);

            if (memberSpellings.walkLength(2) == 1)
            {
                prefixSize = refactorSingleton(
                    enumSpelling,
                    memberSpellings.front);
            }
            else if (minorPrefix.endsWith("_"))
            {
                prefixSize = minorPrefix.length;
            }
            else
            {
                auto underscoreSplit = findSplitBefore(minorPrefix.retro, "_");

                prefixSize = !underscoreSplit[1].empty
                    && underscoreSplit[1].canFind!(x => x != '_')
                    ? underscoreSplit[1].walkLength
                    : minorPrefix.length;
            }
        }

        bool empty()
        {
            return memberSpellings.empty;
        }

        string front()
        {
            return memberSpellings.front[prefixSize .. $];
        }

        void popFront()
        {
            memberSpellings.popFront();
        }
    }

    return Range(enumSpelling, memberSpellings);
}

void translateEnumDef(Output output, Context context, Cursor cursor)
{
    import std.algorithm;
    import std.format : format;
    import std.range;

    auto variables = cursor.variablesInParentScope();
    auto anonymous = context.shouldBeAnonymous(cursor);
    auto spelling = "enum";

    if (!anonymous || variables || !cursor.isGlobal)
        spelling = "enum " ~ translateIdentifier(context.translateTagSpelling(cursor));

    output.subscopeStrong(cursor.extent, "%s", spelling) in
    {
        auto members = cursor.children
            .filter!(cursor => cursor.kind == CXCursorKind.enumConstantDecl);

        size_t length = members.walkLength();

        if (context.options.renameEnumMembers)
        {
            auto renamed = renameEnumMembers(
                context.translateTagSpelling(cursor),
                map!(x => x.spelling)(members));

            foreach (member, spelling; zip(members, enumerate(renamed)))
            {
                translateEnumConstantDecl(
                    output,
                    context,
                    member,
                    spelling.value.toCamelCase.translateIdentifier,
                    length == spelling.index + 1);
            }
        }
        else
        {
            foreach (index, member; enumerate(members))
            {
                translateEnumConstantDecl(
                    output,
                    context,
                    member,
                    member.spelling,
                    length == index + 1);
            }
        }
    };

    if ((anonymous && variables) || !cursor.isGlobal || context.options.aliasEnumMembers)
        generateEnumAliases(context.globalScope, context, cursor, spelling);
}

void translateEnum(Output output, Context context, Cursor cursor)
{
    auto canonical = cursor.canonical;

    if (!context.alreadyDefined(cursor.canonical))
    {
        translateEnumDef(output, context, canonical.definition);
        context.markAsDefined(cursor);
    }
}
