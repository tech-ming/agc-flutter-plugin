/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2021-2023. All rights reserved.
 */

package com.huawei.agconnectclouddb;

import com.huawei.agconnect.cloud.database.ObjectTypeInfo;

/**
 * 对象类型注册表。
 *
 * <p>插件本身不依赖任何业务对象类型，业务层（app）在启动时
 * 通过 {@link #register(ObjectTypeInfo)} 注入 ObjectTypeInfo，
 * 插件在需要时通过 {@link #get()} 取用。
 *
 * <p>使用方式（在 MainActivity 或 Application 中调用）：
 * <pre>
 *   ObjectTypeRegistry.register(ObjectTypeInfoHelper.getObjectTypeInfo());
 * </pre>
 */
public final class ObjectTypeRegistry {

    private static ObjectTypeInfo sObjectTypeInfo;

    private ObjectTypeRegistry() {}

    /** 由业务层在初始化时注册对象类型信息 */
    public static void register(ObjectTypeInfo objectTypeInfo) {
        sObjectTypeInfo = objectTypeInfo;
    }

    /**
     * 获取已注册的对象类型信息。
     *
     * @throws IllegalStateException 如果业务层未调用 register() 进行注册
     */
    public static ObjectTypeInfo get() {
        if (sObjectTypeInfo == null) {
            throw new IllegalStateException(
                "ObjectTypeInfo 未注册。请在 MainActivity 或 Application 启动时调用 " +
                "ObjectTypeRegistry.register(ObjectTypeInfoHelper.getObjectTypeInfo())。"
            );
        }
        return sObjectTypeInfo;
    }
}
