#! /usr/bin/env python

import uvicorn

from performance_metric_merging_service.performance_metric_merging_service import app

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=9321) # TODO get from env
