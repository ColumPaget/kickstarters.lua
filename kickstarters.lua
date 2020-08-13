require("stream")
require("strutil")
require("dataparser")
require("terminal")
require("time")
require("process")
require("net")

projects={}


function ParseListItem(categories, data)
local toks, tok

toks=strutil.TOKENIZER(data, "\\S", "Q")
tok=toks:next()
tok=toks:next()
while tok ~= nil
do
	if string.sub(tok, 1, 15) == "data-category=\""
	then
	str=strutil.stripQuotes(string.sub(tok,15))
	str=strutil.htmlUnQuote(str)
	P=dataparser.PARSER("json", str)
	if P:value("id") ~= nil
	then
	id=tonumber(P:value("id"))
	categories[P:value("slug")]=P:value("id")
	end

	end
	tok=toks:next()
end

end


function GetCategories()
local S, toks, tok, str
local categories={}

--get any category page, and scrape list of categories out of html
S=stream.STREAM("https://www.kickstarter.com/discover/categories/games/")
if S == nil
then
	Out:puts("~rERROR:~0 failed to connect to kickstarter to get categories list\n");
	return nil
end

str=S:readdoc()

toks=strutil.TOKENIZER(str, "<|>", "m")
tok=toks:next()
while tok ~= nil
do
	if string.sub(tok, 1, 3)=="li " then ParseListItem(categories, tok) end
	tok=toks:next()
end

S:close()

S=stream.STREAM(process.getenv("HOME").."/.starters.categories", "w")
if S ~= nil
then
for cat,code in pairs(categories)
do
	S:writeln(code..":"..cat.."\n")
end
S:close()
end

return categories
end



function LoadCategories()
local S, str, toks, id, catname
local categories={}

S=stream.STREAM(process.getenv("HOME").."/.starters.categories", "r")
if S ~= nil
then
	str=strutil.stripTrailingWhitespace(S:readln())
	toks=strutil.TOKENIZER(str, ":")
	id=toks:next()
	catname=toks:remaining()
	if strutil.strlen(catname) > 0 then categories[catname]=id end
end

return categories
end



--[[ kickstarter top level
projects  
total_hits  897
live_projects_count  9
ref_tag  discovery
term_categories  
seed  2640040
search_url  /discover?term=fighting+game
suggestion  fighting game
has_more  true
]]--

--[[
"name":"Merc","blurb":"I am creating a horde mode video game where you fight waves of enemies with friends.","goal":200000.0,"pledged":12.0,"state":"live","slug":"merc","disable_communication":false,"country":"US","country_displayable_name":"the United States","currency":"USD","currency_symbol":"$","currency_trailing_code":true,"deadline":1585681500,"state_changed_at":1580764055,"created_at":1580450518,"launched_at":1580764054,"staff_pick":false,"is_starrable":true,"backers_count":4,"static_usd_rate":1.0,"usd_pledged":"12.0","converted_pledged_amount":9,"fx_rate":0.779788,"current_currency":"GBP","usd_type":null,"creator"
]]--

function KickStarterProject(item)
local project={}

	project.id=item:value("id")
	project.name=item:value("name")
	project.desc=strutil.unQuote(item:value("blurb"))
	project.desc=string.gsub(project.desc, "\n", " ")
	project.goal=tonumber(item:value("goal"))
	project.pledged=tonumber(item:value("pledged"))
	project.backercount=tonumber(item:value("backers_count"))
	project.state=item:value("state")
	project.starttime=time.formatsecs("%Y/%m/%d", tonumber(item:value("created_at")))
	project.endtime= time.formatsecs("%Y/%m/%d", tonumber(item:value("deadline"))) 
	project.url=item:value("urls/web/project")
	project.category=item:value("category/name")
	project.category_id=item:value("category/id")
	project.location=item:value("location/name")
	project.country=item:value("location/country")
	project.creator=item:value("creator/name")
	project.creator_url=item:value("creator/urls/web/user")

return project
end



function KickStarterSearch(terms, category, location)
local S, P, items, item, proj, url
local query={}
local page=0
local hasmore=true

query.projects={}
query.results=0
while hasmore == true
do
url="https://www.kickstarter.com/projects/search.json?search=&term="..strutil.httpQuote(terms).."&page="..page


if strutil.strlen(category) > 0
then
item=categories[category]
if item ~= nil then url=url.."&category_id="..strutil.httpQuote(item) end
end

--.."&location_id=2442047"

S=stream.STREAM(url)
if S == nil
then
Out:puts("~rERROR:~0 failed to connect to kickstarter\n");
return
end

str=S:readdoc()
if Settings.debug==true then io.stderr:write(str.."\n") end
P=dataparser.PARSER("json", str)
query.total=P:value("total_hits")
query.live=P:value("live_projects_count")

items=P:open("/projects")
item=items:next()
while item ~= nil
do
	proj=KickStarterProject(item)
	if proj.id ~= nil 
	then 
		query.projects[proj.id]=proj 
		query.results=query.results+1
	end
	item=items:next()
end

page=page+1
if page > Settings.pages then break end


if P:value("has_more")=="true"
then
	hasmore=true
else
	hasmore=false
end

end

return query
end



function Help()

print("Usage:  lua kickstarters.lua  <options> [search term] [search term]..")
print()
print("Options:")
print("-D                    enable debugging output")
print("-debug                enable debugging output")
print("-p <url>              use proxy")
print("-proxy <url>          use proxy")
print("-U <name>             set http user-agent")
print("-user-agent <name>    set http user-agent")
print("-c <category>         project category to search in")
print("-cat-list             output a list of available project categories")
print("-p <n>                output 'n' pages of results")
print("-pages <n>            output 'n' pages of results")
print("-?                    this help")
print("-h                    this help")
print("-help                 this help")
print("--help                this help")
print()
print("Proxies:")
print("Proxies are set using a proxy url like 'http://myproxy:1080'. 'socks5://user:password@localhost:8080' or 'sshtunnel://gateway'. Available proxy types are: http, https, socks4, socks5, and sshtunnel. a username and password can be supplied in the url. Sshtunnel proxies are just an ssh server that supports tunneling. The following environment variables can also be set to specifiy a proxy: SOCKS_PROXY, socks_proxy, HTTPS_PROXY, https_proxy, all_proxy, kickstarter_proxy")

end



function Configure(args)
local Settings={}
local query_terms=""
local i, arg

Settings.action=""
Settings.pages=1
Settings.proxy=""
Settings.query_terms=""
Settings.query_category=""
Settings.query_location=""
Settings.debug=false
Settings.user_agent="kickstarters.lua"

if strutil.strlen(Settings.proxy) == 0 then Proxy=process.getenv("SOCKS_PROXY") end
if strutil.strlen(Settings.proxy) == 0 then Proxy=process.getenv("socks_proxy") end
if strutil.strlen(Settings.proxy) == 0 then Proxy=process.getenv("HTTPS_PROXY") end
if strutil.strlen(Settings.proxy) == 0 then Proxy=process.getenv("https_proxy") end
if strutil.strlen(Settings.proxy) == 0 then Proxy=process.getenv("all_proxy") end
if strutil.strlen(Settings.proxy) == 0 then Proxy=process.getenv("kickstarter_proxy") end


for i,arg in ipairs(args)
do
	if arg=="-debug" or arg=="-D" then Settings.debug=true
	elseif arg=="-pages" or arg=="-p"
	then
		Settings.pages=tonumber(args[i+1])
		args[i+1]=""
	elseif arg=="-user-agent" or arg=="-U"
	then
		Settings.user_agent=args[i+1]
		args[i+1]=""
	elseif arg=="-proxy" or arg=="-P"
	then
		Settings.proxy=args[i+1]
		args[i+1]=""
	elseif arg=="-category" or arg=="-c"
	then 
		Settings.query_category=args[i+1]
		args[i+1]=""
	elseif arg=="-cat-list" or arg=="-list-categories" 
	then
		Settings.action="list categories"
	elseif arg=="-?" or arg=="-h" or arg=="-help" or arg=="--help"
	then
		Settings.action="help"
	else
		Settings.query_terms=Settings.query_terms.." "..args[i]
	end
end

return Settings
end


function ListCategories()

for cat,id in pairs(categories)
do
	print(cat)
end

end

function KickStarterQuery(Settings)
local query, key, proj, str

query=KickStarterSearch(Settings.query_terms, Settings.query_category, Settings.query_location)

Out:puts("Outputting "..query.results.." of "..query.total..". "..query.live.." live.".."\n")
for key,proj in pairs(query.projects)
do
	Out:puts("~e~b"..proj.category.."~0 ~e" .. proj.name .. "~0 ".." ~c" .. proj.url .. "~0\n")

	if proj.state=="live" then str="~estate:~0 ~e~ylive~0"
	elseif proj.state=="successful" then str="~estate:~0 ~gsuccess~0"
	elseif proj.state=="failed" then str="~estate:~0 ~rfailed~0"
	else str="~estate:~0 "..proj.state
	end

	str=str.. " ~ebackers:~0 "..proj.backercount.." ~egoal:~0 "..proj.goal
	if proj.pledged > proj.goal
	then 
		str=str .." ~eraised:~0 ~g"..proj.pledged.."~0"
	else
		str=str .." ~eraised:~0 "..proj.pledged
	end

	str=str.." ~estart:~0 ".. proj.starttime.." ~eend:~0 "..proj.endtime
	Out:puts(str.."\n")

	Out:puts("~elocation:~0 " ..proj.location.." ~ecountry:~0 " .. proj.country .. " ~ecreator:~0 " ..proj.creator.. " "..proj.creator_url.."\n")
	Out:puts(proj.desc.."\n\n")
end
end






Out=terminal.TERM()

Settings=Configure(arg)

-- you can set a proxy here
if strutil.strlen(Settings.proxy) > 0 then net.setProxy(Settings.proxy) end
if strutil.strlen(Settings.user_agent) > 0 then process.lu_set("HTTP:UserAgent", Settings.user_agent) end
if Settings.debug==true then process.lu_set("HTTP:Debug","y") end

categories=LoadCategories()
if #categories==0 then categories=GetCategories() end

if Settings.action=="list categories"
then
	ListCategories()
elseif Settings.action=="help"
then
	Help()
else
	KickStarterQuery(Settings)
end
