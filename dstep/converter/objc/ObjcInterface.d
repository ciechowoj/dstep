/**
 * Copyright: Copyright (c) 2011 Jacob Carlborg. All rights reserved.
 * Authors: Jacob Carlborg
 * Version: Initial created: Jan 29, 2012
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */
module dstep.converter.objc.ObjcInterface;

import std.string;

import mambo.core._;

import clang.c.index;
import clang.Cursor;
import clang.Visitor;
import clang.Util;

import dstep.converter.Converter;
import dstep.converter.Declaration;
import dstep.converter.Output;
import dstep.converter.Type;

class ObjcInterface : Declaration
{
	this (Cursor cursor, Cursor parent, Converter converter)
	{
		super(cursor, parent, converter);
	}

	void convert ()
	{
		auto cursor = cursor.objc;

		writeClass(spelling, cursor.superClass.spelling, collectInterfaces(cursor.objc)) in {
			foreach (cursor, parent ; cursor.declarations)
			{
				with (CXCursorKind)
					switch (cursor.kind)
					{
						case CXCursor_ObjCInstanceMethodDecl: convertMethod(cursor.func); break;
						case CXCursor_ObjCClassMethodDecl: convertMethod(cursor.func, true); break;
						case CXCursor_ObjCPropertyDecl: convertProperty(cursor.func); break;
						case CXCursor_ObjCIvarDecl: convertInstanceVariable(cursor); break;
						default: break;
					}
			}
		};
	}

private:
	
	string[] collectInterfaces (ObjcCursor cursor)
	{
		string[] interfaces;

		foreach (cursor , parent ; cursor.protocols)
			interfaces ~= convertIdentifier(cursor.spelling);

		return interfaces;
	}
	
	Block writeClass (string name, string superClassName, string[] interfaces)
	{
		Block block;
		
		block.dg = (void delegate () dg) {
			output.currentClass = new Class;
			output.classes ~= output.currentClass;
			output.currentClass.name = convertIdentifier(name);
			
			if (superClassName.isPresent)
				output.currentClass.superclass ~= convertIdentifier(superClassName);
			
			classInterfaceHelper(interfaces, output.currentClass, dg);
		};
		
		return block;
	}
	
	void classInterfaceHelper (string[] interfaces, Class current, void delegate () dg)
	{
		dg();
	}
	
	void convertMethod (FunctionCursor func, bool classMethod = false, string name = null)
	{
		auto method = new String;
		auto cls = output.currentClass;
		
		name = cls.getMethodName(func, name);
		
		converter.func(func, name, classMethod, method);

		method ~= " [";
		method ~= func.spelling;
		method ~= "];";
		
		
		if (classMethod)
			cls.staticMethods ~= method;
			
		else
			cls.instanceMethods ~= method;
	}
	
	void convertProperty (FunctionCursor cursor)
	{
		
	}
	
	void convertInstanceVariable (Cursor cursor)
	{
		auto var = new String;
		converter.variable(cursor, var);
		output.currentClass.instanceVariables ~= var;
	}
}