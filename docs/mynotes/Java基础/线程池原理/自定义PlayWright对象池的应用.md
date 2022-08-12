# 结合common-pools 自定义创建Playwright池

## 简介

Playwright是微软开源的一个UI自动化测试工具。借助额外的语言支持以及跨现代浏览器引擎Chromium，Firefox和WebKit执行的能力，这使Playwright与Selenium WebDriver处于同一类别，成为所有需要交叉测试的Web测试人员（不仅是JS）的可行测试解决方案浏览器测试功能，适用于复杂的应用程序。

## 产生的问题

在工作中，我们使用到Playwright，每一次用到都需要初始化，打开页面、关闭资源，对于系统来说都是一种消耗

## 解决方案

我结合Apache提供的对象池技术，用Playwright预先创造出来几个页面，做了一个池管理

实现方式如下

> BrowserContextPooledObjectFactory

```java
package xxx.playwright;

import com.microsoft.playwright.*;
import org.apache.commons.pool2.DestroyMode;
import org.apache.commons.pool2.PooledObject;
import org.apache.commons.pool2.PooledObjectFactory;
import org.apache.commons.pool2.impl.DefaultPooledObject;

import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

/**
 * @author lishanbiao
 * @date 2021/7/8
 */
public class BrowserContextPooledObjectFactory implements PooledObjectFactory<BrowserContext> {
		// playwright管理容器
    private static final Map<BrowserContext, Playwright> PLAYWRIGHT_MAP = new ConcurrentHashMap<>();
 		// 激活池中物（playwright），借出之前做的操作，相当于刷新实体
    @Override
    public void activateObject(PooledObject<BrowserContext> p) throws Exception {
        p.getObject().clearCookies();
    }
  
  	// 销毁池中物（playwright）
    @Override
    public void destroyObject(PooledObject<BrowserContext> p) throws Exception {
        BrowserContext browserContext = p.getObject();
        Playwright playwright = PLAYWRIGHT_MAP.remove(browserContext);
        if (playwright != null) {
            playwright.close();
        }
    }
		// 创建池中物（playwright）
    @Override
    public PooledObject<BrowserContext> makeObject() throws Exception {
        Playwright playwright = Playwright.create();
        BrowserContext browserContext = playwright.chromium()
                .launch(new BrowserType.LaunchOptions()
                   //  .setHeadless(false)
                ).newContext(new Browser.NewContextOptions()
                        .setScreenSize(1920, 1080));
        browserContext.newPage();
        PLAYWRIGHT_MAP.put(browserContext, playwright);
        return new DefaultPooledObject<>(browserContext);
    }
		// 归还一个池中物（playwright）时调用，不应该activateObject冲突
    @Override
    public void passivateObject(PooledObject<BrowserContext> p) throws Exception {
        p.getObject().pages().get(0).evaluate("try {window.localStorage.clear()} catch(e){console.log(e)}");
        p.getObject().clearCookies();
        p.getObject().pages().get(0).navigate("about:blank");
    }
  
		// 检测对象是否"有效";Pool中不能保存无效的"对象",因此"后台检测线程"会周期性的检测Pool中"对象"的有效性,如果对象无效则会导致此对象从Pool中移除,并destroy;此外在调用者从Pool获取一个"对象"时,也会检测"对象"的有效性,确保不能讲"无效"的对象输出给调用者;当调用者使用完毕将"对象归还"到Pool时,仍然会检测对象的有效性.所谓有效性,就是此"对象"的状态是否符合预期,是否可以对调用者直接使用;如果对象是Socket,那么它的有效性就是socket的通道是否畅通/阻塞是否超时等.
  	// 这里若要检测，需要在PoolConfig中配置检测项目。
  	// true：检测正常，符合预期；false：异常，销毁对象
    @Override
    public boolean validateObject(PooledObject<BrowserContext> p) {
        return true;
    }
}
```

> PlaywrightUtil

```java
package xxx.playwright;

import cn.com.rmxc.java.commons.json.JsonUtils;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.JsonNode;
import com.microsoft.playwright.*;
import com.microsoft.playwright.options.Cookie;
import com.microsoft.playwright.options.MouseButton;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.apache.commons.pool2.impl.GenericObjectPool;
import org.apache.commons.pool2.impl.GenericObjectPoolConfig;
import org.springframework.stereotype.Component;

import javax.annotation.PreDestroy;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.TimeUnit;
import java.util.stream.Collectors;

/**
 * @author lishanbiao
 * @date 2021/7/8
 */
@Slf4j
public class PlaywrightUtil {

    private static final GenericObjectPool<BrowserContext> OBJECT_POOL;
    private static final Map<String, Page> PAGE_MAP = new HashMap<>();
    private static final String TOKEN_SPLITTER = ";";

    static {
        GenericObjectPoolConfig<BrowserContext> config = new GenericObjectPoolConfig<>();
        config.setMinIdle(4);
        config.setMaxIdle(4);
        OBJECT_POOL = new GenericObjectPool<>(new BrowserContextPooledObjectFactory(), config);
    }

    /**
     * 获取Page对象
     *
     * @param id
     * @return
     * @throws Exception
     */
    public static Page borrowPage(String id) throws Exception {
        Page page = getPage(id);
        if (page == null) {
            page = OBJECT_POOL.borrowObject().pages().get(0);
            putPage(id, page);
        }
        return page;
    }

    /**
     * 归还page
     *
     * @param id
     */
    public static void returnPage(String id) {
        Page page = removePage(id);
        if (page != null) {
            OBJECT_POOL.returnObject(page.context());
        }
    }

    /**
     * 获取cookie
     *
     * @param page
     * @return
     */
    public static String getCookies(Page page) {
        return cookieToString(page.context().cookies());
    }

    /**
     * 获取cookie
     *
     * @param cookies
     * @return
     */
    public static String cookieToString(List<Cookie> cookies) {
        return cookies.stream().map(cookie -> cookie.name + "=" + cookie.value).collect(Collectors.joining(TOKEN_SPLITTER));
    }

    /**
     * 退出playwright
     */
    public static void exitPlaywright() {
        OBJECT_POOL.close();
    }

    /**
     * 存放page
     *
     * @param key
     * @param page
     */
    private static void putPage(String key, Page page) {
        PAGE_MAP.put(key, page);
    }

    /**
     * 获取page
     *
     * @param key
     * @return
     */
    private static Page getPage(String key) {
        return PAGE_MAP.get(key);
    }

    /**
     * 删除page
     *
     * @param key
     */
    private static Page removePage(String key) {
        return PAGE_MAP.remove(key);
    }

    /**
     * 图片日志
     *
     * @param id
     */
    public static void pictureLog(String id) {
        Page page = getPage(id);
        if (page != null) {
            pictureLog(id, page);
        } else {
            log.error("Playwright截图未找到page对象, id:{}", id);
        }
    }

    /**
     * 图片日志
     *
     * @param id
     * @param page
     */
    public static void pictureLog(String id, Page page) {
        try {
            Path path = Files.createTempFile("playwright-log-", ".jpg");
            page.screenshot(new Page.ScreenshotOptions().setFullPage(true).setPath(path));
            log.info("截图完成,path:{}", path.toAbsolutePath());
        } catch (Throwable t) {
            log.error("截图失败", t);
        }
    }

    /**
     * 清空localStorage
     *
     * @param page
     */
    public static void clearLocalStorage(Page page) {
        page.evaluate("window.localStorage.clear();");
    }

    /**
     * 滑动滑块
     *
     * @param page
     * @param slideElementPath
     * @param slideLength
     * @param steps
     */
    public static void slide(Page page, String slideElementPath, int slideLength, int steps) {
        slide(page, page.waitForSelector(slideElementPath, new Page.WaitForSelectorOptions().setTimeout(TimeUnit.SECONDS.toMillis(5))), slideLength, steps);
    }

    /**
     * 滑动滑块
     *
     * @param page
     * @param elementHandle
     * @param slideLength
     * @param steps
     */
    public static void slide(Page page, ElementHandle elementHandle, int slideLength, int steps) {
        Mouse mouse = page.mouse();
        mouse.move(elementHandle.boundingBox().x, elementHandle.boundingBox().y);
        mouse.down(new Mouse.DownOptions().setButton(MouseButton.LEFT));
        mouse.move(elementHandle.boundingBox().x + slideLength, elementHandle.boundingBox().y, new Mouse.MoveOptions().setSteps(steps));
        mouse.up();
    }

    /**
     * 解析token
     *
     * @param token
     * @param key
     * @return
     */
    public static String parseToken(String token, String key) {
        for (String s : token.split(TOKEN_SPLITTER)) {
            String tokenKey = s.substring(0, s.indexOf("="));
            if (tokenKey.equals(key)) {
                return s.substring(s.indexOf("=") + 1, s.length() - 1);
            }
        }
        return "";
    }

    public static List<Cookie> token2Cookie(String token) {
        List<String> list = JsonUtils.fromJson(token, new TypeReference<List<String>>() {});
        List<com.microsoft.playwright.options.Cookie> cookieList = new ArrayList<>();
        list.forEach(cookie1 -> {
            OldToken oldToken = JsonUtils.fromJson(cookie1, OldToken.class);
            Cookie cookie2 = new Cookie(oldToken.getName(), oldToken.getValue());
            cookieList.add(cookie2);
        });
        return cookieList;
    }

    @Component
    public static class TerminateHandler {
        /**
         * 手动关闭playwright
         */
        @PreDestroy
        public void preDestroy() {
            PlaywrightUtil.exitPlaywright();
        }

    }

    /**
     * 解析cookie转json，后续作废
     *
     * @param token
     * @return
     */
    public static String parseCookieToJson(String token) {
        String[] tokenArray = token.split(";");
        List<String> tokens = new ArrayList<>();
        for (String s : tokenArray) {
            String name = s.substring(0, s.indexOf('='));
            String value = s.substring(s.indexOf('=') + 1);
            tokens.add(JsonUtils.toJson(new OldToken(name, value)));
        }
        return JsonUtils.toJson(tokens);
    }

    /**
     * 解析json转cookies
     *
     * @param token
     * @return
     */
    public static List<Cookie> parseJsonToCookie(String token) {
        List<Cookie> cookies = new ArrayList<>();
        JsonNode jsonNode = JsonUtils.readTree(token);
        for (JsonNode node : jsonNode) {
            Cookie cookie = new Cookie(node.get("name").asText(), node.get("value").asText());
            cookie.setPath(node.get("path").asText());
            if(node.hasNonNull("url")){
                cookie.setUrl(node.get("url").asText());
            }
            if(node.hasNonNull("domain")){
                cookie.setDomain(node.get("domain").asText());
            }
            cookie.setExpires(node.get("expires").asDouble());
            cookie.setSecure(node.get("secure").asBoolean());
            cookies.add(cookie);
        }
        return cookies;
    }
}
```

