/*
* Copyright (c) 2016, Alcatel-Lucent Inc
* All rights reserved.
*
* Redistribution and use in source and binary forms, with or without
* modification, are permitted provided that the following conditions are met:
*     * Redistributions of source code must retain the above copyright
*       notice, this list of conditions and the following disclaimer.
*     * Redistributions in binary form must reproduce the above copyright
*       notice, this list of conditions and the following disclaimer in the
*       documentation and/or other materials provided with the distribution.
*     * Neither the name of the copyright holder nor the names of its contributors
*       may be used to endorse or promote products derived from this software without
*       specific prior written permission.
*
* THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
* ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
* WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
* DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY
* DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
* (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
* LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
* ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
* (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
* SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

var ENV = require("system").env,
    FILE = require("file"),
	OS = require("os"),
	JAKE = require("jake"),
    task = JAKE.task,
    CLEAN = require("jake/clean").CLEAN,
    FileList = JAKE.FileList,
    framework = require("cappuccino/jake").framework,
    configuration = ENV["CONFIG"] || ENV["CONFIGURATION"] || ENV["c"] || "Release";

framework ("Bambou", function(task)
{
    task.setBuildIntermediatesPath(FILE.join(ENV["CAPP_BUILD"], "Bambou.build", configuration));
    task.setBuildPath(FILE.join(ENV["CAPP_BUILD"], configuration));

    task.setProductName("Bambou");
    task.setIdentifier("net.net.nuagenetworks.bambou");
    task.setVersion("1.0");
    task.setAuthor("Antoine Mercadal");
    task.setEmail("antoine@nuagenetworks.net");
    task.setSummary("Bambou");
    task.setSources(new FileList("*.j", "Bambou/*.j"));
    task.setResources(new FileList("Resources/**/**"));
    task.setInfoPlistPath("Info.plist");

    if (configuration === "Debug")
        task.setCompilerFlags("-DDEBUG -g");
    else
        task.setCompilerFlags("-O2");
});

task("build", ["Bambou"]);

task("debug", function()
{
    ENV["CONFIG"] = "Debug"
    JAKE.subjake(["."], "build", ENV);
});

task("release", function()
{
    ENV["CONFIG"] = "Release"
    JAKE.subjake(["."], "build", ENV);
});

task ("documentation", function()
{
   OS.system("doxygen Bambou.doxygen")
});

task("test", ["test-only"]);

task("test-only", function()
{
    ENV["OBJJ_INCLUDE_PATHS"] = "Frameworks";

    OS.system("capp gen -fl . --force");

    var tests = new FileList('Test/*Test.j'),
        cmd = ["ojtest"].concat(tests.items()),
        cmdString = cmd.map(OS.enquote).join(" "),
        code = OS.system(cmdString);

    OS.system("rm -rf Frameworks");

    if (code !== 0)
        OS.exit(code);
});

task ("default", ["release"]);
task ("docs", ["documentation"]);
task ("all", ["release", "debug", "documentation"]);
