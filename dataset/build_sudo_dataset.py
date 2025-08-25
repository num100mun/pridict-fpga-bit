import asyncio
import os
from stagehand import Stagehand, StagehandConfig
from dotenv import load_dotenv

load_dotenv()


async def main():
    config = StagehandConfig(
        env="BROWSERBASE",
        api_key=os.getenv("BROWSERBASE_API_KEY"),
        project_id=os.getenv("BROWSERBASE_PROJECT_ID"),
        model_name="gpt-4o",
        model_api_key=os.getenv("MODEL_API_KEY")
    )

    stagehand = Stagehand(config)

    try:
        await stagehand.init()
        page = stagehand.page

        await page.goto("https://docs.stagehand.dev/")
        await page.act("click the quickstart link")

        result = await page.extract("extract the main heading of the page")

        print(f"Extracted: {result}")

    finally:
        await stagehand.close()


if __name__ == "__main__":
    asyncio.run(main())