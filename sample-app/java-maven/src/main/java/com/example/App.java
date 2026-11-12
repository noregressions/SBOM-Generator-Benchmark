package com.example;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.apache.commons.lang3.StringUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.Map;

/** Tiny application whose only job is to have a few real dependencies for SBOM tools to find. */
public class App {
    private static final Logger LOG = LoggerFactory.getLogger(App.class);

    public static void main(String[] args) throws Exception {
        var mapper = new ObjectMapper();
        var json = mapper.writeValueAsString(Map.of("greeting", StringUtils.capitalize("hello sbom")));
        LOG.info(json);
    }
}
