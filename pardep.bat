@echo off
setlocal EnableDelayedExpansion

set REGION=ap-south-1

echo ==========================================
echo 🚀 PARALLEL STACK DEPLOYMENT STARTED
echo ==========================================

echo.
echo 🚀 Phase 1 → Independent Heavy Stacks (Parallel)...
echo ------------------------------------------

for /L %%i in (1,1,5) do (
    echo Launching indep-heavy-%%i
    start /B aws cloudformation create-stack ^
        --region %REGION% ^
        --stack-name indep-heavy-%%i ^
        --template-body file://template1.yaml ^
        --capabilities CAPABILITY_IAM
)

echo ✅ Phase 1 Requests Submitted
timeout /t 2 >nul

echo.
echo 🚀 Phase 2 → Parent Heavy Stacks (Parallel)...
echo ------------------------------------------

for /L %%i in (1,1,20) do (
    echo Launching parent-heavy-%%i
    start /B aws cloudformation create-stack ^
        --region %REGION% ^
        --stack-name parent-heavy-%%i ^
        --template-body file://template2.yaml
)

echo ✅ Phase 2 Requests Submitted

echo.
echo ⏳ Waiting for Parent Stacks to Reach CREATE_COMPLETE...
echo ------------------------------------------

:waitloop
set ALL_DONE=true

for /L %%i in (1,1,20) do (

    for /f %%s in ('aws cloudformation describe-stacks ^
        --stack-name parent-heavy-%%i ^
        --query "Stacks[0].StackStatus" ^
        --output text 2^>nul') do (

        echo parent-heavy-%%i → %%s

        if NOT "%%s"=="CREATE_COMPLETE" (
            set ALL_DONE=false
        )
    )
)

if "!ALL_DONE!"=="false" (
    timeout /t 5 >nul
    goto waitloop
)

echo.
echo ✅ All Parent Stacks Ready!
echo ------------------------------------------

echo.
echo 🚀 Phase 3 → Dependent Stacks (Parallel)...
echo ------------------------------------------

for /L %%i in (1,1,20) do (

    set PARENT_INDEX=%%i

    :adjustLoop
    if !PARENT_INDEX! GTR 15 (
        set /a PARENT_INDEX-=15
        goto adjustLoop
    )

    echo Launching dependent-%%i → parent-heavy-!PARENT_INDEX!

    start /B aws cloudformation create-stack ^
        --region %REGION% ^
        --stack-name dependent-%%i ^
        --template-body file://template3.yaml ^
        --parameters ParameterKey=ParentExportName,ParameterValue=parent-heavy-!PARENT_INDEX!-BucketExport ^
        --capabilities CAPABILITY_IAM
)

echo.
echo ==========================================
echo 🎯 ALL STACK REQUESTS SUBMITTED
echo ==========================================

pause