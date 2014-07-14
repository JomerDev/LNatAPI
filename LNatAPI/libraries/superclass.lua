local superclass = {
	_VERSION = "superclass v0.0.1"
	_DESCRIPTION = "Object Oriented Classes in Lua"
}

--[[
-- @function sets the metatables of class dictionaries
-- @param aClass - a class
--]]
local function _setClassDictionariesMetatables(aClass)
  local dict = aClass.__instanceDict
  dict.__index = dict

  local super = aClass.super
  if super then
    local superStatic = super.static
    setmetatable(dict, super.__instanceDict)
    setmetatable(aClass.static, { __index = function(_,k) return dict[k] or superStatic[k] end })
  else
    setmetatable(aClass.static, { __index = function(_,k) return dict[k] end })
  end
end

--[[
-- @function sets the metatable of a class
-- @param aClass - a class
--]]
local function _setClassMetatable(aClass)
  setmetatable(aClass, {
    __tostring = function() return "class " .. aClass.name end,
    __index    = aClass.static,
    __newindex = aClass.__instanceDict,
    __call     = function(self, ...) return self:new(...) end
  })
end

--[[
-- @function creates a class
-- @param name - the name of the class
-- @param super - the superclass of a class
--]]
local function _createClass(name, super)
  local aClass = { name = name, super = super, static = {}, __mixins = {}, __instanceDict={} }
  aClass.subclasses = setmetatable({}, {__mode = "k"})

  _setClassDictionariesMetatables(aClass)
  _setClassMetatable(aClass)

  return aClass
end

--[[
-- @function creates a lookup metamethod
-- @param aClass - a class
-- @param name - the name of the class
--]]
local function _createLookupMetamethod(aClass, name)
  return function(...)
    local method = aClass.super[name]
    assert( type(method)=='function', tostring(aClass) .. " doesn't implement metamethod '" .. name .. "'" )
    return method(...)
  end
end

--[[
-- @function sets the metamethods of a class
-- @param aClass - a class
--]]
local function _setClassMetamethods(aClass)
  for _,m in ipairs(aClass.__metamethods) do
    aClass[m]= _createLookupMetamethod(aClass, m)
  end
end

--[[
-- @function sets the default initialize method
-- @param aClass - a class
-- @param super - the superclass
--]]
local function _setDefaultInitializeMethod(aClass, super)
  aClass.initialize = function(instance, ...)
    return super.initialize(instance, ...)
  end
end

--[[
-- @function includes the mixin
-- @param aClass - a class
-- qparam mixin - a mixin
--]]
local function _includeMixin(aClass, mixin)
  assert(type(mixin)=='table', "mixin must be a table")
  for name,method in pairs(mixin) do
    if name ~= "included" and name ~= "static" then aClass[name] = method end
  end
  if mixin.static then
    for name,method in pairs(mixin.static) do
      aClass.static[name] = method
    end
  end
  if type(mixin.included)=="function" then mixin:included(aClass) end
  aClass.__mixins[mixin] = true
end


--[[
-- @use creates an object class
--]]
local Object = _createClass("Object", nil)

--[[
-- @use all the metamethods in a table
--]]
Object.static.__metamethods = { '__add', '__call', '__concat', '__div', '__ipairs', '__le',
                                '__len', '__lt', '__mod', '__mul', '__pairs', '__pow', '__sub',
                                '__tostring', '__unm'}


--[[
-- @function allocates a static object
--]]
function Object.static:allocate()
  assert(type(self) == 'table', "Make sure that you are using 'Class:allocate' instead of 'Class.allocate'")
  return setmetatable({ class = self }, self.__instanceDict)
end

--[[
-- @function creates a new static objects
--]]
function Object.static:new(...)
  local instance = self:allocate()
  instance:initialize(...)
  return instance
end

--[[
-- @function creates a subclass for a class
-- @param name - the name of the class
--]]
function Object.static:subclass(name)
  assert(type(self) == 'table', "Make sure that you are using 'Class:subclass' instead of 'Class.subclass'")
  assert(type(name) == "string", "You must provide a name(string) for your class")

  local subclass = _createClass(name, self)
  _setClassMetamethods(subclass)
  _setDefaultInitializeMethod(subclass, self)
  self.subclasses[subclass] = true
  self:subclassed(subclass)

  return subclass
end

--[[
-- @function nil
--]]
function Object.static:subclassed(other) end

--[[
-- @function checks if a class is the subclass of another
-- @param other - the other class
--]]
function Object.static:isSubclassOf(other)
  return type(other)                   == 'table' and
         type(self)                    == 'table' and
         type(self.super)              == 'table' and
         ( self.super == other or
           type(self.super.isSubclassOf) == 'function' and
           self.super:isSubclassOf(other)
         )
end

--[[
-- @function includes something
--]]
function Object.static:include( ... )
  assert(type(self) == 'table', "Make sure you that you are using 'Class:include' instead of 'Class.include'")
  for _,mixin in ipairs({...}) do _includeMixin(self, mixin) end
  return self
end

--[[
-- @function includes mixin
-- @param mixin - a mixin
--]]
function Object.static:includes(mixin)
  return type(mixin)          == 'table' and
         type(self)           == 'table' and
         type(self.__mixins)  == 'table' and
         ( self.__mixins[mixin] or
           type(self.super)           == 'table' and
           type(self.super.includes)  == 'function' and
           self.super:includes(mixin)
         )
end

--[[
-- @function initializes something
--]]
function Object:initialize() end

--[[
-- @function returns 
--]]
function Object:__tostring() return "instance of " .. tostring(self.class) end

--[[
-- @function checks if the object is an instance of another
-- @param aClass - a class
--]]
function Object:isInstanceOf(aClass)
  return type(self)                == 'table' and
         type(self.class)          == 'table' and
         type(aClass)              == 'table' and
         ( aClass == self.class or
           type(aClass.isSubclassOf) == 'function' and
           self.class:isSubclassOf(aClass)
         )
end

--[[
-- @function creates a superclass
--]]
function superclass.class(name, super, ...)
  super = super or Object
  return super:subclass(name, ...)
end

middleclass.Object = Object

setmetatable(superclass, { __call = function(_, ...) return superclass.class(...) end })

return superclass