# -*- encoding=utf8 -*-
#合并皮肤目录并导出资源
import os
import json
import ccsexport
import utils
from Util import Util
import pysvn


from Tkinter import *

config = {
	"selectId":0,
	"exportDir":""
}

if Util.isExist("export.db"):
	content = Util.getStringFromFile("export.db")
	config = json.loads(content)
 

os.chdir("../")
excludes = ["tools"]
for root, dirs, files in os.walk("./", topdown=True):
    dirs[:] = [d for d in dirs if d not in excludes]
    break


window = Tk()
window.title("合并版本UI导出工具")
window.geometry('300x500')  # 这里的乘是小x
group = LabelFrame(window, text="请选择要导出的皮肤", padx=5, pady=5)
group.pack(padx=10, pady=10)

selectVar = StringVar()
selectVar.set(config["selectId"])
for index in range(len(dirs)):
	b = Radiobutton(group, text=dirs[index], variable=selectVar, value=index)
	b.pack(anchor=W)


textLabel = Label(window, text="请输入资源导出路径 例如:\nE:\\gitproject\\client-quanguo)", padx=10)
textLabel.pack()

textVar = StringVar()
textVar.set(config["exportDir"])
inputBox = Entry(window,width =200,borderwidth=3,textvariable=textVar)
inputBox.pack()


def getParent(itemName,ExportList):
		path = itemName+"/ui.json"
		content = Util.getStringFromFile(path)
		uiConfig = json.loads(content)
		parent = uiConfig["parent"]
		if parent.strip() != u'':
			ExportList.append(parent)
			getParent(parent,ExportList)

def btnExportClick():
    selectId = int(selectVar.get())
    exportDir = inputBox.get()
    config["exportDir"] = exportDir
    config["selectId"] = selectId
    print "SVN UPDATE"
    client = pysvn.Client()
    client.update('./')
    curItemName = dirs[selectId]
    ExportList = [curItemName]
    getParent(curItemName,ExportList)
    targetDir = "../skinlocal_"+curItemName
    Util.ensureDir(targetDir)
    for itemName in reversed(ExportList):
		print "copy=",itemName
		utils.copytree(itemName, targetDir)
	
    print u"拷贝资源成功"
    os.chdir("tools")
    json_str = json.dumps(config)
    Util.writeStringToFile("export.db",json_str)
    targetDir = "../../skinlocal_" + curItemName
	#发布资源
    print(u"发布资源中")
    ccsexport.export(targetDir, os.path.join(exportDir, "res", "ui"), True)
    print(u"发布成功")
    print(u"按任意键退出")
    raw_input()
    window.destroy()
 

b = Button(window, text='导出资源',command=btnExportClick).pack()

# 注意，这时候窗口还是不会显示的...
# 除非执行下面的这条代码！！！！！
window.mainloop()



