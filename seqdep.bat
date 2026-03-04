@echo off
set REGION=ap-south-1

echo 🚀 Phase 1 → Independent Heavy Stacks (WITH EC2)...

for /L %%i in (1,1,5) do (
    echo Creating indep-heavy-%%i
    aws cloudformation create-stack ^
        --region %REGION% ^
        --stack-name indep-heavy-%%i ^
        --template-body file://template1.yaml ^
        --capabilities CAPABILITY_IAM
)

echo 🚀 Phase 2 → Parent Heavy Stacks (NO EC2)...

for /L %%i in (1,1,20) do (
    echo Creating parent-heavy-%%i
    aws cloudformation create-stack ^
        --region %REGION% ^
        --stack-name parent-heavy-%%i ^
        --template-body file://template2.yaml
)

echo ⏳ Waiting for ALL Parent Stacks to Reach CREATE_COMPLETE...

:waitloop

set ALL_DONE=true

for /L %%i in (1,1,20) do (

    for /f %%s in ('aws cloudformation describe-stacks ^
        --stack-name parent-heavy-%%i ^
        --query "Stacks[0].StackStatus" ^
        --output text') do (

        echo parent-heavy-%%i → %%s

        if NOT "%%s"=="CREATE_COMPLETE" (
            set ALL_DONE=false
        )
    )
)

if "%ALL_DONE%"=="false" (
    timeout /t 5 >nul
    goto waitloop
)

echo ✅ All Parent Stacks Ready!

echo 🚀 Phase 3 → Dependent Stacks (Parallel)...

for /L %%i in (1,1,20) do (

    set /a PARENT_INDEX=(%%i-1) %%%% 15 + 1

    echo Launching dependent-%%i → parent-heavy-!PARENT_INDEX!

    start cmd /c aws cloudformation create-stack ^
        --region %REGION% ^
        --stack-name dependent-%%i ^
        --template-body file://template3.yaml ^
        --parameters ParameterKey=ParentExportName,ParameterValue=parent-heavy-!PARENT_INDEX!-BucketExport ^
        --capabilities CAPABILITY_IAM
)