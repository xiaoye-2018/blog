
# 建议设置环境变量
go env GOROOT      # go 安装目录，包含go可执行文件(bin), 标准库(src: 源码, pkg：编译后的)
go env GOPATH      # go 相关三方依赖库。 bin:可自行文件（bee，proto工具）， pkg： 依赖库( 内部mod 目录)

# modules目录，  GOPATH 一样的
go env GOMODCACHE  # 相关的依赖目录，包括不同版本的go工具链 （项目中定义的go版本跟安装的不同时，会自动下载）
# 查看下载的工具链
ls $GOPATH/pkg/mod/golang.org/

# 新建项目
# 初始化一个新的 Go 模块，创建 go.mod 文件，模块名为 wechatdll
go mod init wechatdll
# 整理和清理模块依赖，确保 go.mod 和 go.sum 文件准确反映项目的实际依赖。 即当代码中有引入依赖时，执行下面命令会自动引入到go.mod文件中
go mod tidy


go.sum 文件确保所有开发者使用相同版本的依赖


# 国内设置代理
go env -w GOPROXY=https://goproxy.cn,direct


bee： 一个便捷的beego的开发工具，可以使用命令生成controller、文档等

# 安装依赖，不包含二进制文件
go get github.com/beego/bee
# 会将二进制下载到$GOPATH/bin，  v2最新版
go install github.com/beego/bee@v1.12.0
go install github.com/beego/bee/v2@latest

# 直接运行项目， v2运行会清空 原来的router文件。导致无法运行
bee run

#生成路由映射：commentsRouter.go     只有v2 才行了
bee generate routers

router.go: 添加对应的namespace，相当于controller类
beego.NSNamespace

commentsRouter.go： 添加controller类中的每个url 请求方法。 命令自动创建
beego.GlobalControllerRouter



构建目标文件：
SET CGO_ENABLED=0  # 禁用CGO，因为交叉编译不支持
SET GOOS=linux # windows
SET GOARCH=amd64
go build [-tags linux] -o output_file_name main.go