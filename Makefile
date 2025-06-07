# ==============================================================================
# 定义全局 Makefile 变量方便后面引用

COMMON_SELF_DIR := $(dir $(lastword $(MAKEFILE_LIST)))
# 项目根目录
PROJ_ROOT_DIR := $(abspath $(shell cd $(COMMON_SELF_DIR)/ && pwd -P))
# 构建产物、临时文件存放目录
OUTPUT_DIR := $(PROJ_ROOT_DIR)/_output
# Protobuf 文件存放路径
APIROOT := $(PROJ_ROOT_DIR)/pkg/api

# ==============================================================================
# 定义版本相关变量

## 指定应用使用的 version 包，会通过 `-ldflags -X` 向该包中指定的变量注入值
VERSION_PACKAGE=github.com/onexstack/miniblog/pkg/version
## 定义 VERSION 语义化版本号
ifeq ($(origin VERSION), undefined)
VERSION := $(shell git describe --tags --always --match='v*')
endif

## 检查代码仓库是否是 dirty（默认dirty）
GIT_TREE_STATE:="dirty"
ifeq (, $(shell git status --porcelain 2>/dev/null))
    GIT_TREE_STATE="clean"
endif
GIT_COMMIT:=$(shell git rev-parse HEAD)

GO_LDFLAGS += \
    -X $(VERSION_PACKAGE).gitVersion=$(VERSION) \
    -X $(VERSION_PACKAGE).gitCommit=$(GIT_COMMIT) \
    -X $(VERSION_PACKAGE).gitTreeState=$(GIT_TREE_STATE) \
    -X $(VERSION_PACKAGE).buildDate=$(shell date -u +'%Y-%m-%dT%H:%M:%SZ')

# ==============================================================================
# 定义默认目标为 all
.DEFAULT_GOAL := all

# 定义 Makefile all 伪目标，执行 `make` 时，会默认会执行 all 伪目标
.PHONY: all
all: tidy format build add-copyright

# ==============================================================================
# 定义其他需要的伪目标

.PHONY: build
build: tidy # 编译源码，依赖 tidy 目标自动添加/移除依赖包.
	@go build -v -ldflags "$(GO_LDFLAGS)" -o $(OUTPUT_DIR)/mb-apiserver $(PROJ_ROOT_DIR)/cmd/mb-apiserver/main.go

.PHONY: format
format: # 格式化 Go 源码.
	@gofmt -s -w ./

.PHONY: add-copyright
add-copyright: # 添加版权头信息.
	@addlicense -v -f $(PROJ_ROOT_DIR)/scripts/boilerplate.txt $(PROJ_ROOT_DIR) --skip-dirs=third_party,vendor,$(OUTPUT_DIR)

.PHONY: tidy
tidy: # 自动添加/移除依赖包.
	@go mod tidy

.PHONY: clean
clean: # 清理构建产物、临时文件等.
	@-rm -vrf $(OUTPUT_DIR)

.PHONY: protoc
protoc: # 编译 protobuf 文件.
	@echo "===========> Generate protobuf files"
	@echo "APIROOT: $(APIROOT)"
	@protoc                                              \
		--proto_path=$(APIROOT)                          \
		--proto_path=$(PROJ_ROOT_DIR)/third_party/protobuf \
		--go_out=paths=source_relative:$(APIROOT)        \
		--go-grpc_out=paths=source_relative:$(APIROOT)   \
		$(shell find $(APIROOT) -name *.proto)

# --proto_path  # 指定 protobuf 文件的搜索路径（即 import 语句查找 .proto 文件的路径）
# --go_out      # 指定 生成的 Go 代码的输出路径，并控制生成的文件路径如何映射到 .proto 文件 路径。
# --go-grpc_out # 指定 生成的 gRPC 代码的输出路径，并控制生成的文件路径如何映射到 .proto 文件路径。
# $(shell find $(APIROOT) -name *.proto)  # 自动查找 $(APIROOT) 目录下所有的 .proto 文件，并作为 protoc 的输入文件
# paths=source_relative 表示 生成的 Go 文件的路径与 .proto 文件的路径相对一致。
  #例如，如果 miniblog.proto 在 $(APIROOT)/pkg/api/apiserver/v1/miniblog.proto，那么生成的 miniblog.pb.go 也会在 $(APIROOT)/pkg/api/apiserver/v1/miniblog.pb.go。
