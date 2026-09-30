# Few-Shot Examples

These anchor the expected output. Comments are shown in Chinese because these sample runs resolved Chinese; the structure and coverage are what matter, not the language.

## Few-shot 1: Java at Detailed density (before → after)

Before:

```java
/**
 * 报表模板服务
 * @author example-author
 * @date 2024-11-06
 */
public class ReportTemplateService {
    private final ReportTemplateMapper mapper;
    private static final int MAX_NAME_LEN = 50;

    public ReportTemplate save(ReportTemplateVO vo) {
        if (vo.getName() == null || vo.getName().length() > MAX_NAME_LEN) {
            throw new BizException("name invalid");
        }
        ReportTemplate entity = convert(vo);
        if (entity.getId() == null) {
            entity.setCreateTime(new Date());
            mapper.insert(entity);
        } else {
            mapper.updateById(entity);
        }
        return entity;
    }

    public ReportTemplateMapper getMapper() { return mapper; }
}
```

After:

```java
/**
 * 报表模板服务：负责报表模板的保存（新增 / 更新）等维护操作。
 * 名称长度等业务校验在服务层完成，持久化交由 ReportTemplateMapper。
 *
 * @author example-author
 * @date 2024-11-06
 */
public class ReportTemplateService {
    /** 报表模板持久化 Mapper，负责模板表的增删改查 */
    private final ReportTemplateMapper mapper;
    /** 模板名称最大长度，超过视为非法入参 */
    private static final int MAX_NAME_LEN = 50;

    /**
     * 保存报表模板：id 为空走新增（补记创建时间），否则按 id 更新。
     *
     * @param vo 前端提交的模板视图对象，name 必填且长度不超过 MAX_NAME_LEN
     * @return 保存后的模板实体，新增时含回填的主键
     * @throws BizException 名称为空或超长时抛出
     */
    public ReportTemplate save(ReportTemplateVO vo) {
        // 入参校验：名称必填且不超长，不满足直接终止保存
        if (vo.getName() == null || vo.getName().length() > MAX_NAME_LEN) {
            throw new BizException("name invalid");
        }
        // VO 转实体，隔离前端入参结构与持久化结构
        ReportTemplate entity = convert(vo);
        if (entity.getId() == null) {
            // 新增分支：首次落库，补记创建时间
            entity.setCreateTime(new Date());
            mapper.insert(entity);
        } else {
            // 更新分支：按主键覆盖已有模板
            mapper.updateById(entity);
        }
        return entity;
    }

    public ReportTemplateMapper getMapper() { return mapper; }
}
```

Note what happened:
- The existing class comment was enhanced — original wording kept, `@author` / `@date` preserved, no new authorship tags added
- Every field and the method got doc comments; every logic step got a line comment
- `getMapper()` stayed untouched — boilerplate exemption

## Few-shot 2: the same method at Selective density

```java
    public ReportTemplate save(ReportTemplateVO vo) {
        if (vo.getName() == null || vo.getName().length() > MAX_NAME_LEN) {
            throw new BizException("name invalid");
        }
        ReportTemplate entity = convert(vo);
        // id 为空视为新增：补记创建时间后落库，否则按主键更新
        if (entity.getId() == null) {
            entity.setCreateTime(new Date());
            mapper.insert(entity);
        } else {
            mapper.updateById(entity);
        }
        return entity;
    }
```

Only the insert-vs-update convention earns a comment; the obvious validation and conversion lines stay bare.

## Few-shot 3: TypeScript at Detailed density (fields generalize to interface properties)

```typescript
/** 报表查询条件：分页 + 模板名称模糊匹配 */
interface ReportQuery {
  /** 页码，从 1 开始 */
  page: number;
  /** 模板名称关键字，空串表示不过滤 */
  keyword: string;
}

/**
 * 查询报表模板列表。
 * @param query 查询条件（分页 + 关键字）
 * @returns 命中的模板数组，无结果时为空数组
 */
async function listTemplates(query: ReportQuery): Promise<Template[]> {
  // 关键字预处理：去掉首尾空格，避免空白串被当成有效过滤条件
  const kw = query.keyword.trim();
  // ...
}
```

## Few-shot 4: contradiction found while annotating

Existing code:

```java
    /** 计算订单含税总金额 */
    public BigDecimal totalAmount(Order order) {
        return order.getItems().stream()
                .map(Item::getPreTaxPrice)
                .reduce(BigDecimal.ZERO, BigDecimal::add);
    }
```

The comment claims "含税" but the code sums pre-tax prices. Do not rewrite the comment; the final report carries:

| 位置 | 注释声称 | 代码实际 |
|---|---|---|
| `OrderService.totalAmount` | 计算含税总金额 | 按 `getPreTaxPrice` 汇总，未加税 |

## Few-shot 5: Git Uncommitted Mode, end-to-end interaction

```
1. CWD 不是 git 仓库 → 扫描子目录发现 3 个仓库，2 个有未提交变更（repo-a、repo-b）
   → 交互提问选仓库 → 用户选 repo-a
2. 变更收集：staged 2 个文件 + unstaged 3 个 + untracked 1 个
   → 过滤后剩 5 个源码文件（pom.xml 等配置文件被排除）
3. 一次交互确认（合并为一次提问）：
   - 范围：A「只注释变更代码」（14 个变更点 / 5 个文件）或 B「涉及文件全量」（5 个文件）→ 用户选 B
   - 密度：详细（推荐）/ 精选 → 用户选 详细
   - 语言：范围内既有注释以中文为主 → 默认中文（声明即可，不提问）
4. 列出 5 个文件清单，逐个顺序编辑，不再二次确认
5. 汇总报告：
   | 文件 | 文档注释 | 行注释 |
   |---|---|---|
   | ReportTemplateService.java | 6 | 18 |
   | ... | ... | ... |
   矛盾清单：1 处（totalAmount 注释与实现不符）
```
